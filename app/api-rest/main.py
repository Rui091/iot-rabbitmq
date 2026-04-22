import os
import json
import psycopg2
from psycopg2.extras import RealDictCursor
import pika
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Task Management API")

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "tasksdb")
DB_USER = os.environ.get("DB_USER", "dbadmin")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "SuperSecretDbPassword123!")
RABBITMQ_URL = os.environ.get("RABBITMQ_URL", "amqp://admin:SuperSecretMqPassword123!@localhost:5672")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def init_db():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS tasks (
              task_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              status    VARCHAR(50) NOT NULL,
              date      TIMESTAMP NOT NULL DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS orders (
              order_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              details     TEXT,
              created_at  TIMESTAMP NOT NULL DEFAULT NOW()
            );
        """)
        conn.commit()
        cur.close()
        conn.close()
        print("Database initialized successfully.")
    except Exception as e:
        print(f"Error initializing DB: {e}")

@app.on_event("startup")
def startup_event():
    init_db()

def publish_message(queue_name: str, message: dict):
    try:
        parameters = pika.URLParameters(RABBITMQ_URL)
        connection = pika.BlockingConnection(parameters)
        channel = connection.channel()
        channel.queue_declare(queue=queue_name, durable=True)
        channel.basic_publish(
            exchange='',
            routing_key=queue_name,
            body=json.dumps(message),
            properties=pika.BasicProperties(delivery_mode=2)
        )
        connection.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to publish to RabbitMQ: {e}")

class TaskCreate(BaseModel):
    status: str

class TaskUpdate(BaseModel):
    task_id: str
    status: str

class TaskDelete(BaseModel):
    task_id: str

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/tasks")
def get_tasks():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM tasks ORDER BY date DESC")
        tasks = cur.fetchall()
        cur.close()
        conn.close()
        return {"tasks": tasks}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tasks/{task_id}")
def get_task(task_id: str):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM tasks WHERE task_id = %s", (task_id,))
        task = cur.fetchone()
        cur.close()
        conn.close()
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        return task
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/asimiento")
def create_asimiento(task: TaskCreate):
    publish_message("tasks_queue", {"action": "create", "status": task.status})
    return {"message": "Create task request queued"}

@app.put("/asimiento")
def update_asimiento(task: TaskUpdate):
    publish_message("update_queue", {"action": "update", "task_id": task.task_id, "status": task.status})
    return {"message": "Update task request queued"}

@app.delete("/asimiento")
def delete_asimiento(task: TaskDelete):
    publish_message("delete_queue", {"action": "delete", "task_id": task.task_id})
    return {"message": "Delete task request queued"}
