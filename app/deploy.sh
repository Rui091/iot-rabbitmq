#!/bin/bash
set -e

REGION="us-east-1"

echo "Getting AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Logging into ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_BASE}

SERVICES=("api-rest" "consumer-pool" "consumer-delete" "update-task")

for SERVICE in "${SERVICES[@]}"; do
    echo "========================================="
    echo "Building and pushing $SERVICE..."
    echo "========================================="
    
    cd $SERVICE
    docker build -t ${SERVICE} .
    docker tag ${SERVICE}:latest ${ECR_BASE}/${SERVICE}:latest
    docker push ${ECR_BASE}/${SERVICE}:latest
    cd ..
done

echo "========================================="
echo "✅ All services successfully deployed to ECR!"
echo "ECS will automatically start the new containers."
