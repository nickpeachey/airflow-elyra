#!/bin/bash
# Script to configure Airflow connections for LocalStack

set -e

echo "Configuring Airflow connections for LocalStack..."

# Get the Airflow scheduler pod
SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}')

echo "Using scheduler pod: $SCHEDULER_POD"

# Create AWS connection for LocalStack
echo "Creating AWS connection for LocalStack..."
kubectl exec -n airflow $SCHEDULER_POD -- airflow connections add 'aws_default' \
    --conn-type 'aws' \
    --conn-login 'test' \
    --conn-password 'test' \
    --conn-extra '{"region_name": "us-east-1", "endpoint_url": "http://localstack-service.localstack.svc.cluster.local:4566"}' || echo "Connection already exists"

# Create S3 bucket for logs in LocalStack
echo "Creating S3 bucket for logs..."
kubectl exec -n airflow $SCHEDULER_POD -- python3 -c "
import boto3
import os

# Configure LocalStack S3 client
s3_client = boto3.client(
    's3',
    endpoint_url='http://localstack-service.localstack.svc.cluster.local:4566',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

# Create bucket for logs
try:
    s3_client.create_bucket(Bucket='airflow-logs')
    print('✅ Created airflow-logs bucket')
except Exception as e:
    print(f'Bucket might already exist: {e}')

# List buckets to verify
buckets = s3_client.list_buckets()
print('Available buckets:')
for bucket in buckets['Buckets']:
    print(f'  - {bucket[\"Name\"]}')
"

echo "Airflow connections configured successfully!"
