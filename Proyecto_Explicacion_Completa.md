# Explicación Completa: Proyecto IoT RabbitMQ

Este documento detalla a profundidad la arquitectura, el diseño y el flujo de ejecución del proyecto "Task Management API". Todo el ecosistema está desplegado en AWS utilizando Infraestructura como Código (Terraform) y microservicios en contenedores Docker.

## 1. Visión General de la Arquitectura

El proyecto está diseñado bajo un modelo de **microservicios asíncronos** usando el patrón de **Message Broker** para desacoplar la escritura en la base de datos de la API principal.

Los componentes de AWS utilizados son:
- **Application Load Balancer (ALB):** Punto de entrada.
- **Elastic Container Service (ECS) Fargate:** Computación serverless para contenedores.
- **Relational Database Service (RDS):** Base de datos PostgreSQL.
- **Elastic Compute Cloud (EC2):** Servidor para alojar RabbitMQ.
- **Elastic Container Registry (ECR):** Repositorio privado de imágenes Docker.

### Flujo de Datos
1. El usuario envía una petición HTTP al **ALB**.
2. El ALB enruta la petición al servicio **API REST** en ECS Fargate.
3. Si la petición es de lectura (`GET /tasks`), la API consulta directamente a **PostgreSQL (RDS)** y devuelve la respuesta al instante.
4. Si la petición es de escritura (`POST`, `PUT`, `DELETE`), la API **no bloquea** el sistema escribiendo en la base de datos. En su lugar, empaqueta la solicitud en un mensaje JSON y la publica en una cola dentro de **RabbitMQ (EC2)**. La API responde inmediatamente con "Request queued".
5. En segundo plano, los contenedores **Consumers** (Pool, Delete, Update) que están "escuchando" a RabbitMQ recogen los mensajes de las colas, los procesan y ejecutan las consultas SQL pesadas o modificaciones directamente en la base de datos **PostgreSQL**.

## 2. Componentes de la Infraestructura (Terraform)

El código de infraestructura está modularizado para mantener buenas prácticas y escalabilidad.

- **Networking:** Crea una Virtual Private Cloud (VPC) con 2 subredes públicas (con salida directa a internet vía Internet Gateway) y 2 subredes privadas (sin acceso desde internet, pero con salida a través de un NAT Gateway).
- **Security Groups (Firewalls):** Aplican el "principio de mínimo privilegio". Por ejemplo, la base de datos solo permite conexiones provenientes de la API y de los Consumers. Nadie más en internet puede tocar la base de datos.
- **ALB:** Balanceador de capa 7 configurado para escuchar en el puerto 80 (HTTP) y hacer un enrutamiento hacia la API REST. Incluye Health Checks para detectar si la API se cae y reiniciar el contenedor automáticamente.
- **RDS (PostgreSQL):** Instancia de base de datos administrada por AWS. Se le configuran backups automáticos (retención de 7 días).
- **EC2 (RabbitMQ):** Debido a restricciones en entornos académicos (Learner Lab), usamos una instancia EC2 (t3.micro, Amazon Linux 2, 8GB EBS) que instala Docker en su script de inicialización (`user_data`) y despliega RabbitMQ automáticamente al encenderse.
- **ECR:** Crea 4 repositorios privados para guardar el código compilado de la API y los workers. Configura reglas de limpieza para borrar imágenes viejas (solo mantiene las últimas 5 para no generar costos extras).
- **ECS (Cluster & Fargate):** Crea el cluster, el rol de ejecución de IAM (usando el `LabRole` preexistente) y las "Task Definitions". Aquí se inyectan como variables de entorno todas las contraseñas, URLs de bases de datos y direcciones de RabbitMQ de forma segura.

## 3. Código de la Aplicación (Python)

Toda la lógica está en Python 3.12 usando librerías modernas y eficientes.

### La API REST (FastAPI)
Se utilizó **FastAPI** por su excelente rendimiento y su documentación automática. 
- Contiene un evento de inicio (`startup`) que crea las tablas `tasks` y `orders` en PostgreSQL automáticamente si no existen.
- Usa `psycopg2` para conectarse a la base de datos.
- Usa `pika` para abrir conexiones con RabbitMQ y publicar mensajes.

### Los Consumers (Workers)
Son scripts de Python muy ligeros que corren en un ciclo infinito (`while True`).
- Utilizan `pika` para suscribirse a una cola específica (ej. `tasks_queue`).
- Cuando detectan un mensaje, lo decodifican (JSON), ejecutan el cambio en SQL (`INSERT`, `UPDATE` o `DELETE`) y finalmente envían un "Acknowledge" (`basic_ack`) a RabbitMQ confirmando que el mensaje fue procesado con éxito para que lo borre de la cola.

## 4. Seguridad y Costos (AWS Free Tier)

- **Costos Controlados:** El diseño de EC2 para RabbitMQ fue degradado a Amazon Linux 2 con un disco de 8GB para que, sumado al almacenamiento de la base de datos RDS (20GB), el total (28GB) se mantenga por debajo del límite gratuito mensual de AWS de 30GB.
- **Aislamiento de Red:** Los motores de RabbitMQ, la API y los Consumers viven en *subredes privadas*. No tienen IP pública, haciéndolos invisibles a los hackers en internet.
- **Manejo de Secretos:** Las contraseñas de la base de datos nunca se escriben en los archivos. Terraform las pide al momento de ejecutar mediante variables de entorno en la memoria de la consola (`TF_VAR_db_password`), inyectándolas directo a AWS.

---
*Fin del documento de explicación del proyecto. Este archivo Markdown puede ser impreso o exportado como PDF directamente.*
