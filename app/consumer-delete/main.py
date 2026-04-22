import os
import json
import time
import psycopg2
import pika

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "tasksdb")
DB_USER = os.environ.get("DB_USER", "dbadmin")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "SuperSecretDbPassword123!")
RABBITMQ_URL = os.environ.get("RABBITMQ_URL", "amqp://admin:SuperSecretMqPassword123!@localhost:5672")
QUEUE_NAME = os.environ.get("QUEUE_NAME", "delete_queue")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def callback(ch, method, properties, body):
    try:
        message = json.loads(body)
        print(f"Received message: {message}")
        if message.get("action") == "delete" and "task_id" in message:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("DELETE FROM tasks WHERE task_id = %s", (message["task_id"],))
            conn.commit()
            cur.close()
            conn.close()
            print(f"Successfully deleted task {message['task_id']}")
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        print(f"Error processing message: {e}")

def main():
    while True:
        try:
            parameters = pika.URLParameters(RABBITMQ_URL)
            connection = pika.BlockingConnection(parameters)
            channel = connection.channel()
            channel.queue_declare(queue=QUEUE_NAME, durable=True)
            channel.basic_qos(prefetch_count=1)
            channel.basic_consume(queue=QUEUE_NAME, on_message_callback=callback)
            print(f"Waiting for messages on {QUEUE_NAME}...")
            channel.start_consuming()
        except pika.exceptions.AMQPConnectionError:
            print("Connection to RabbitMQ lost, retrying in 5 seconds...")
            time.sleep(5)
        except Exception as e:
            print(f"Unexpected error: {e}")
            time.sleep(5)

if __name__ == '__main__':
    main()
