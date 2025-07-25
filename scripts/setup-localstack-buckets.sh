#!/bin/bash

# Setup LocalStack S3 Buckets Script
# This script creates the necessary S3 buckets in LocalStack for notebook data

set -e

echo "📦 Setting up LocalStack S3 Buckets"
echo "===================================="
echo ""

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/localstack -n localstack

# Setup port forwarding if not already running
echo "🌐 Setting up port forwarding..."
if ! pgrep -f "kubectl port-forward.*localstack.*4566" > /dev/null; then
    kubectl port-forward -n localstack svc/localstack-service 4566:4566 &
    PORTFORWARD_PID=$!
    echo "Started port forward with PID: $PORTFORWARD_PID"
    sleep 5
else
    echo "Port forward already running"
fi

# Wait for LocalStack to be accessible
echo "⏳ Waiting for LocalStack API to be accessible..."
for i in {1..30}; do
    if curl -s http://localhost:4566/health > /dev/null 2>&1; then
        echo "✅ LocalStack is accessible"
        break
    fi
    echo "  Attempt $i/30 - waiting for LocalStack..."
    sleep 2
done

# Create required buckets
echo "🪣 Creating S3 buckets..."
buckets=("data-lake" "processed-data" "data-engineering-bucket" "airflow-logs" "elyra-pipelines" "mlpipeline")

for bucket in "${buckets[@]}"; do
    echo "  Creating bucket: $bucket"
    aws --endpoint-url=http://localhost:4566 s3 mb s3://$bucket 2>/dev/null || echo "    Bucket $bucket already exists"
done

# Upload sample data
echo "📄 Uploading sample data..."
if [ -f "data/sales_data.csv" ]; then
    curl -X PUT "http://localhost:4566/data-lake/sales_data.csv" \
         --data-binary @data/sales_data.csv \
         -H "Content-Type: text/csv" 2>/dev/null || echo "  Failed to upload sample data"
    echo "  Uploaded sales_data.csv to data-lake bucket"
else
    echo "  No sample data file found (data/sales_data.csv)"
fi

# List created buckets
echo "📋 Created buckets:"
aws --endpoint-url=http://localhost:4566 s3 ls

echo "✅ LocalStack S3 buckets setup completed!"
echo ""
echo "📋 Available buckets:"
echo "  • data-lake: For raw data ingestion"
echo "  • processed-data: For processed data output"
echo "  • data-engineering-bucket: For general data engineering tasks"
echo "  • airflow-logs: For Airflow log storage"
echo "  • elyra-pipelines: For Elyra pipeline artifacts"
echo "  • mlpipeline: For KFP/MinIO compatibility"
echo ""
