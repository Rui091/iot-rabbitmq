#!/bin/bash
set -e

# Install and start Docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
sleep 5

# Run RabbitMQ container with management plugin
docker run -d \
  --name rabbitmq \
  --restart always \
  -e RABBITMQ_DEFAULT_USER=${rabbitmq_username} \
  -e RABBITMQ_DEFAULT_PASS=${rabbitmq_password} \
  -p 5672:5672 \
  -p 15672:15672 \
  rabbitmq:3-management
