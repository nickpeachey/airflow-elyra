#!/bin/bash

# LocalStack S3 Bucket Viewer Script
# This script demonstrates different ways to view and interact with LocalStack S3 buckets

set -e

echo "🪣 LocalStack S3 Bucket Management"
echo "=================================="
echo ""

# Check if LocalStack is running
echo "📊 Checking LocalStack status..."
if ! curl -s http://localhost:4566/health >/dev/null 2>&1; then
    echo "❌ LocalStack is not accessible at http://localhost:4566"
    echo "   Make sure LocalStack is running and port-forwarded:"
    echo "   kubectl port-forward -n localstack svc/localstack-service 4566:4566"
    exit 1
fi
echo "✅ LocalStack is running"
echo ""

# Method 1: AWS CLI
echo "🔧 Method 1: Using AWS CLI"
echo "============================"
echo ""
echo "List buckets:"
echo "aws --endpoint-url=http://localhost:4566 s3 ls"
echo ""
aws --endpoint-url=http://localhost:4566 s3 ls 2>/dev/null || echo "No buckets found or AWS CLI not configured"
echo ""

echo "Create a test bucket (if needed):"
echo "aws --endpoint-url=http://localhost:4566 s3 mb s3://test-bucket"
echo ""

# Method 2: curl REST API
echo "🌐 Method 2: Using REST API (curl)"
echo "===================================="
echo ""
echo "Check LocalStack health:"
echo "curl http://localhost:4566/health"
echo ""
curl -s http://localhost:4566/health | jq . 2>/dev/null || curl -s http://localhost:4566/health
echo ""

echo "List buckets via S3 API:"
echo "curl http://localhost:4566/"
echo ""
curl -s "http://localhost:4566/" 2>/dev/null | head -10 || echo "Error accessing S3 API"
echo ""

# Method 3: Python boto3 (show code example)
echo "🐍 Method 3: Using Python boto3"
echo "================================="
echo ""
cat << 'EOF'
# Python code to list buckets:
import boto3

s3_client = boto3.client(
    's3',
    endpoint_url='http://localhost:4566',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

# List buckets
response = s3_client.list_buckets()
for bucket in response['Buckets']:
    print(f"Bucket: {bucket['Name']}")
    
    # List objects in bucket
    objects = s3_client.list_objects_v2(Bucket=bucket['Name'])
    if 'Contents' in objects:
        for obj in objects['Contents']:
            print(f"  - {obj['Key']}")
    else:
        print("  (empty)")
EOF
echo ""

# Method 4: From within Jupyter/Airflow pods
echo "🔬 Method 4: From within Kubernetes pods"
echo "=========================================="
echo ""
echo "From Jupyter pod:"
echo "kubectl exec -n jupyter deployment/jupyter-lab -- python3 -c \"import boto3; ...\""
echo ""
echo "From Airflow pod:"
echo "kubectl exec -n airflow airflow-scheduler-0 -c scheduler -- python3 -c \"import boto3; ...\""
echo ""

# Show useful commands
echo "💡 Useful Commands"
echo "==================="
echo ""
echo "Create bucket:     aws --endpoint-url=http://localhost:4566 s3 mb s3://my-bucket"
echo "Upload file:       aws --endpoint-url=http://localhost:4566 s3 cp file.txt s3://my-bucket/"
echo "Download file:     aws --endpoint-url=http://localhost:4566 s3 cp s3://my-bucket/file.txt ."
echo "Delete bucket:     aws --endpoint-url=http://localhost:4566 s3 rb s3://my-bucket --force"
echo "List objects:      aws --endpoint-url=http://localhost:4566 s3 ls s3://my-bucket/"
echo ""

echo "🔗 LocalStack URLs"
echo "=================="
echo ""
echo "Health check:      http://localhost:4566/health"
echo "S3 API:           http://localhost:4566/"
echo "LocalStack UI:     http://localhost:4566/_localstack/health"
echo ""

echo "✅ Done! Use any of the methods above to interact with LocalStack S3."
