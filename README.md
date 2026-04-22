# IoT RabbitMQ - Task Management API

Este proyecto despliega una arquitectura de microservicios en AWS utilizando contenedores (ECS Fargate), bases de datos relacionales (RDS PostgreSQL) y mensajería asíncrona (RabbitMQ). Toda la infraestructura está automatizada con **Terraform** y el código de la aplicación está escrito en **Python (FastAPI y Pika)**.

## 🏗 Arquitectura del Sistema

1. **Application Load Balancer (ALB):** Punto de entrada público de la API.
2. **API REST (FastAPI en ECS Fargate):** Recibe las peticiones HTTP, consulta la base de datos para lecturas (GET) y encola mensajes en RabbitMQ para escrituras (POST, PUT, DELETE).
3. **RabbitMQ (EC2):** Message Broker que gestiona 3 colas distintas (`tasks_queue`, `delete_queue`, `update_queue`).
4. **PostgreSQL (RDS):** Base de datos administrada que almacena la información de las tareas.
5. **Consumers / Workers (Python en ECS Fargate):** 
   - `consumer-pool`: Escucha creaciones y las guarda en BD.
   - `consumer-update`: Escucha actualizaciones y modifica la BD.
   - `consumer-delete`: Escucha borrados y elimina de la BD.

---

## 📂 Estructura del Proyecto

- `/infra`: Código de Terraform (separado en módulos reutilizables y el entorno `dev`).
- `/app`: Código fuente de la API y los 3 Consumers en Python, con sus respectivos `Dockerfile`.
- `/0_dev_environment`: Entorno Docker local para ejecutar Terraform sin instalar dependencias en tu PC.

---

## 🚀 Instrucciones de Despliegue

### 1. Configurar Entorno de Desarrollo
Para no instalar Terraform localmente, usamos un contenedor Docker:
```powershell
docker build -t iot_dev_environment_image ./0_dev_environment
docker run -it --name iot_dev_environment -v "C:\Ruta\A\Tu\Proyecto:/workspace" iot_dev_environment_image bash
```

### 2. Configurar Credenciales de AWS
Dentro del contenedor Docker, configura las credenciales de tu cuenta de AWS (Learner Lab):
```bash
mkdir -p ~/.aws
cat > ~/.aws/credentials << 'EOF'
[default]
aws_access_key_id = TU_ACCESS_KEY
aws_secret_access_key = TU_SECRET_KEY
aws_session_token = TU_SESSION_TOKEN
EOF
```

### 3. Crear la Infraestructura (Terraform)
En el contenedor Docker, navega a `infra/environments/dev` y despliega:
```bash
# Exportar contraseñas seguras para la DB y RabbitMQ
export TF_VAR_db_username="dbadmin"
export TF_VAR_db_password="TuPasswordSeguro123!"
export TF_VAR_rabbitmq_username="admin"
export TF_VAR_rabbitmq_password="TuPasswordSeguro123!"

terraform init
terraform plan -out=tfplan -var-file=terraform.tfvars
terraform apply tfplan
```
Al finalizar, Terraform te devolverá la URL del Load Balancer (ALB) y los repositorios ECR.

### 4. Desplegar la Aplicación a AWS (Docker Push)
Abre una terminal en tu PC (fuera del contenedor). Inicia sesión en AWS ECR y sube los 4 microservicios:

```powershell
$ECR = "TU_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"

# Ejemplo para la API REST (Repetir para los consumers)
cd app/api-rest
docker build -t api-rest .
docker tag api-rest:latest $ECR/api-rest:latest
docker push $ECR/api-rest:latest
```
*ECS detectará las nuevas imágenes automáticamente y arrancará los servidores.*

---

## 🧪 Cómo Probar la API

Usa la URL de tu Application Load Balancer obtenida en el paso 3.

**1. Health Check (Verificar que está viva):**
```bash
curl http://<TU_ALB_URL>/health
# Respuesta: {"status": "ok"}
```

**2. Listar Tareas:**
```bash
curl http://<TU_ALB_URL>/tasks
```

**3. Crear Tarea (Asíncrono vía RabbitMQ):**
```bash
curl -X POST http://<TU_ALB_URL>/asimiento \
     -H "Content-Type: application/json" \
     -d '{"status": "En proceso"}'
# Respuesta: {"message": "Create task request queued"}
```
*Si esperas un par de segundos y vuelves a listar las tareas, verás la nueva tarea creada.*
