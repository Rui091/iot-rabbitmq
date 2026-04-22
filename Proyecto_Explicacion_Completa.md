# Documentación Técnica Exhaustiva: Proyecto IoT RabbitMQ

Este documento detalla a nivel de experto la arquitectura, diseño, decisiones técnicas y flujo de ejecución del proyecto "Task Management API". Todo el ecosistema está desplegado en AWS utilizando Infraestructura como Código (Terraform) y microservicios en contenedores Docker.

---

## 1. Visión General de la Arquitectura

El proyecto resuelve un problema clásico de rendimiento: si una API HTTP se bloquea esperando a que una base de datos guarde información, la API colapsa bajo mucha carga. Para solucionar esto, hemos diseñado un modelo de **microservicios asíncronos** usando un **Message Broker (RabbitMQ)** para desacoplar la escritura de la lectura.

### Flujo Exacto de Datos (Paso a Paso)

1. **El Usuario hace una Petición HTTP:** El usuario envía un `POST /asimiento` al balanceador de carga.
2. **ALB (Application Load Balancer):** Recibe la petición en el puerto 80. Revisa que el servicio esté sano y envía el tráfico al contenedor de la API REST que está corriendo en ECS Fargate.
3. **API REST (FastAPI):** Recibe el `POST`. En lugar de hacer un `INSERT` en PostgreSQL (lo cual tomaría tiempo), la API construye un JSON con la tarea y lo envía a la cola `tasks_queue` de RabbitMQ.
4. **Respuesta Inmediata:** RabbitMQ recibe el mensaje en milisegundos. La API le responde al usuario HTTP 200 OK con el mensaje: "Request queued". El usuario no tuvo que esperar a la base de datos.
5. **Consumer (Worker en Segundo Plano):** Tenemos contenedores de Python aislados (ej. `consumer-pool`) que están todo el tiempo escuchando la cola `tasks_queue`.
6. **Procesamiento Asíncrono:** Cuando llega el mensaje a RabbitMQ, RabbitMQ se lo envía al Consumer. El Consumer ejecuta el `INSERT` pesado en la base de datos PostgreSQL.
7. **Confirmación (Ack):** Una vez guardado en la base de datos, el Consumer le avisa a RabbitMQ que el trabajo fue exitoso (`basic_ack`). RabbitMQ elimina el mensaje de la cola.

---

## 2. Explicación de la Infraestructura en AWS (Terraform)

Para no depender de clics manuales en la consola de AWS, todo se programó en Terraform, estructurado en módulos. A continuación se explica cada componente desplegado:

### A. Networking (Redes)
Creamos nuestra propia nube privada (VPC). 
- **Subredes Públicas:** Tienen salida a internet directo (Internet Gateway). Aquí vive el Load Balancer para poder recibir peticiones del mundo exterior.
- **Subredes Privadas:** No tienen conexión directa desde el exterior. Aquí viven los servidores (ECS, RDS, RabbitMQ). Si necesitan descargar algo de internet, lo hacen a través de un **NAT Gateway**. Esto hace imposible que un hacker ataque los servidores directamente.

### B. Security Groups (Grupos de Seguridad / Firewalls)
Se configuraron reglas hiper-estrictas (Principio de Mínimo Privilegio):
- **ALB SG:** Solo permite tráfico entrante en el puerto 80 desde cualquier lugar (`0.0.0.0/0`).
- **API SG:** Solo permite recibir tráfico si este proviene exactamente del *ALB SG*.
- **RabbitMQ SG:** Solo permite conexiones en el puerto 5672 (AMQP) si provienen de la *API SG* o de los *Consumers SG*.
- **RDS SG:** Solo permite tráfico en el puerto 5432 si proviene de la *API SG* (para leer) o de los *Consumers SG* (para escribir).

### C. Amazon EC2 (Para RabbitMQ)
Originalmente, RabbitMQ se desplegaría usando el servicio administrado "Amazon MQ". Sin embargo, las políticas de seguridad del entorno educativo (AWS Learner Lab) prohíben su creación (`mq:CreateBroker`). 
- **Solución:** Levantamos un servidor EC2 (`t3.micro`) con el sistema operativo ligero *Amazon Linux 2* y un disco duro básico de 8GB. A través del script `user_data`, el servidor instala Docker automáticamente al encenderse y levanta un contenedor de RabbitMQ.

### D. Amazon RDS (PostgreSQL)
Base de datos relacional `db.t3.micro`. Maneja respaldos automáticos de 7 días. El usuario administrador (`dbadmin`) y la contraseña no están quemados en el código, se inyectan a través de variables de entorno de Terraform (`TF_VAR_db_password`) por seguridad.

### E. Amazon ECS Fargate (Contenedores Serverless)
Es el orquestador de contenedores. Fargate significa que no administramos servidores; AWS nos presta capacidad de cómputo temporal.
Desplegamos 4 servicios (Task Definitions):
- **api-rest:** Balanceado por el ALB.
- **consumer-pool:** Instancia doble (desired_count = 2) para procesar más rápido.
- **consumer-update:** Una instancia.
- **consumer-delete:** Una instancia.
Todos usan el rol `LabRole` por requerimiento del Learner Lab.

---

## 3. Explicación del Código de las Aplicaciones (Python)

Las aplicaciones están programadas en Python 3.12 y alojadas en Docker.

### A. API REST (`app/api-rest/main.py`)
Utiliza **FastAPI**, el framework más rápido de Python para APIs.
- Usa `psycopg2` para hacer las consultas `SELECT` a la base de datos de manera síncrona.
- Usa un evento `@app.on_event("startup")` que se asegura de crear las tablas `tasks` y `orders` usando SQL (`CREATE TABLE IF NOT EXISTS`) en cuanto la API arranca, para que la base de datos nunca esté vacía estructuralmente.
- Usa `pika` para enviar payloads JSON a RabbitMQ sin esperar a la respuesta de la base de datos.

### B. Consumers (`app/consumer-*/main.py`)
Los tres workers son casi idénticos en estructura:
- Se conectan a RabbitMQ y declaran que van a consumir una cola (`basic_consume`).
- Usan `prefetch_count=1`. Esto asegura que RabbitMQ envíe los mensajes de uno en uno, balanceando la carga equitativamente si hay varios consumers.
- Contienen un bloque `try-except`. Si la base de datos falla al guardar, el script lanza una excepción, y *no* envía la confirmación (`ack`). Esto obliga a RabbitMQ a re-encolar el mensaje y volverlo a intentar, asegurando cero pérdida de datos.

---

## 4. Estrategia de Control de Costos (AWS Free Tier)

El entorno fue ajustado estrictamente para no generar facturación:
- **Almacenamiento (EBS):** El límite gratuito es 30GB al mes. Usamos 20GB para la base de datos RDS y 8GB para el servidor EC2 de RabbitMQ (Total: 28GB). Quedando a salvo por 2GB.
- **Computación:** ECS Fargate y t3.micro entran en los márgenes de uso temporal gratuito, asumiendo que los recursos se destruyen al finalizar la sesión del laboratorio.
- **ECR Lifecycle Policy:** Se configuró una política en los repositorios de imágenes Docker para eliminar automáticamente cualquier imagen vieja, conservando únicamente las últimas 5 compilaciones. Esto evita pagar almacenamiento extra de Docker.

---

## 5. Resumen del Ciclo de Vida del Despliegue

1. El administrador inicia el entorno de Docker local.
2. Exporta contraseñas seguras a la memoria RAM.
3. Ejecuta `terraform apply`, lo que orquesta toda la infraestructura en el orden correcto de dependencias (Redes -> Seguridad -> Base de Datos -> EC2 -> ECS).
4. El administrador corre el script `deploy.sh` que compila el código en Python, lo empaqueta en imágenes de Docker y las sube a los registros ECR privados de AWS.
5. ECS detecta el código, descarga la imagen e inicia los microservicios.
6. El sistema completo queda en línea, escalable, balanceado y aislado de ataques externos.

*Documento Generado Exitosamente.*
