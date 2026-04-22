#!/bin/bash
set -e

# Install and start Docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Wait for Docker to be fully ready
sleep 5

# Run PostgreSQL 15 container
docker run -d \
  --name postgres \
  --restart always \
  -e POSTGRES_DB=tasksdb \
  -e POSTGRES_USER=${db_username} \
  -e POSTGRES_PASSWORD=${db_password} \
  -p 5432:5432 \
  postgres:15
