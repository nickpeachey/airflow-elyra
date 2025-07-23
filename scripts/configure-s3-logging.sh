#!/bin/bash

# Configure Airflow with S3 Logging and Deploy PySpark DAG
# ========================================================

set -e

echo "🔧 Configuring Airflow for S3 logging and deploying PySpark DAG..."

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Kubernetes cluster not found. Please run ./scripts/setup-complete.sh first"
    exit 1
fi

echo "📊 Upgrading Airflow with S3 logging configuration..."

# Upgrade Airflow with new configuration
helm upgrade airflow apache-airflow/airflow --version 1.16.0\
    -n airflow \
    -f helm/airflow-values-simple.yaml \
    --wait \
    --timeout=10m

echo "⏳ Waiting for Airflow pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=airflow -n airflow --timeout=300s

# Wait a bit more for services to stabilize
sleep 30

echo "🔌 Creating AWS connection in Airflow for LocalStack..."

# Get Airflow webserver pod
AIRFLOW_POD=$(kubectl get pods -n airflow -l component=webserver -o jsonpath='{.items[0].metadata.name}')

if [ -z "$AIRFLOW_POD" ]; then
    echo "❌ Could not find Airflow webserver pod"
    exit 1
fi

echo "📦 Found Airflow webserver pod: $AIRFLOW_POD"

# Create AWS connection for LocalStack
kubectl exec -n airflow $AIRFLOW_POD -- airflow connections delete aws_default || true
kubectl exec -n airflow $AIRFLOW_POD -- airflow connections add aws_default \
    --conn-type aws \
    --conn-host localstack-service.localstack.svc.cluster.local:4566 \
    --conn-login test \
    --conn-password test \
    --conn-extra '{"endpoint_url": "http://localstack-service.localstack.svc.cluster.local:4566", "region_name": "us-east-1"}'

echo "✅ AWS connection configured"

# Deploy the new PySpark DAG
echo "📄 Deploying PySpark S3 DAG..."
kubectl cp dags/pyspark_s3_example.py $AIRFLOW_POD:/opt/airflow/dags/ -n airflow

# Trigger DAG refresh
echo "🔄 Refreshing Airflow DAGs..."
kubectl exec -n airflow $AIRFLOW_POD -- airflow dags reserialize

echo "🏗️ Creating S3 bucket structure..."

# Ensure required buckets exist in LocalStack
LOCALSTACK_POD=$(kubectl get pods -n localstack -l app=localstack -o jsonpath='{.items[0].metadata.name}')

if [ -z "$LOCALSTACK_POD" ]; then
    echo "❌ Could not find LocalStack pod"
    exit 1
fi

echo "📦 Found LocalStack pod: $LOCALSTACK_POD"

# Create required S3 buckets
kubectl exec -n localstack $LOCALSTACK_POD -- aws --endpoint-url=http://localhost:4566 s3 mb s3://data-engineering-bucket || true
kubectl exec -n localstack $LOCALSTACK_POD -- aws --endpoint-url=http://localhost:4566 s3 mb s3://airflow-logs || true

# Verify buckets
echo "📋 Current S3 buckets:"
kubectl exec -n localstack $LOCALSTACK_POD -- aws --endpoint-url=http://localhost:4566 s3 ls

echo ""
echo "🎉 Configuration complete!"
echo ""
echo "📊 Access Points:"
echo "- Airflow UI: http://localhost:8080 (admin/admin)"
echo "- Jupyter Lab: http://localhost:8888"
echo "- LocalStack: http://localhost:4566"
echo ""
echo "🔥 New PySpark DAG Available:"
echo "- DAG ID: pyspark_s3_data_pipeline"
echo "- Features: Sample data generation, processing, S3 storage"
echo "- Logs: Now stored in S3 bucket 'airflow-logs'"
echo ""
echo "🚀 To trigger the DAG manually:"
echo "kubectl exec -n airflow $AIRFLOW_POD -- airflow dags trigger pyspark_s3_data_pipeline"
echo ""
echo "📊 To view S3 buckets and data:"
echo "./scripts/view-s3-buckets.sh"
