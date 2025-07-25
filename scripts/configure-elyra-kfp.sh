#!/bin/bash

# Configure Elyra KFP Runtime Script
# This script creates the correct KFP runtime configuration for Elyra

set -e

echo "⚙️  Configuring Elyra Kubeflow Pipelines Runtime"
echo "==============================================="
echo ""

# Wait for Jupyter pod to be ready
echo "⏳ Waiting for Jupyter pod to be ready..."
kubectl wait --for=condition=ready pod -l app=jupyter-lab -n jupyter --timeout=300s

# Get pod name
JUPYTER_POD=$(kubectl get pods -n jupyter -l app=jupyter-lab -o jsonpath='{.items[0].metadata.name}')
echo "📋 Found Jupyter pod: $JUPYTER_POD"

# Get MinIO credentials
echo "🔑 Retrieving MinIO credentials..."
MINIO_ACCESS_KEY=$(kubectl get secret mlpipeline-minio-artifact -n kubeflow -o jsonpath='{.data.accesskey}' | base64 -d)
MINIO_SECRET_KEY=$(kubectl get secret mlpipeline-minio-artifact -n kubeflow -o jsonpath='{.data.secretkey}' | base64 -d)

# Create KFP runtime configuration
echo "📝 Creating KFP runtime configuration..."
cat > /tmp/kubeflow-pipelines.json << EOF
{
  "display_name": "Kubeflow Pipelines",
  "schema_name": "kfp",
  "metadata": {
    "api_endpoint": "http://ml-pipeline.kubeflow:8888",
    "engine": "Argo",
    "auth_type": "NO_AUTHENTICATION",
    "cos_endpoint": "http://minio-service.kubeflow:9000",
    "cos_bucket": "mlpipeline",
    "cos_auth_type": "USER_CREDENTIALS",
    "cos_username": "$MINIO_ACCESS_KEY",
    "cos_password": "$MINIO_SECRET_KEY",
    "runtime_type": "KUBEFLOW_PIPELINES",
    "runtime_image": "jupyter-elyra:latest"
  }
}
EOF

# Copy runtime configuration to Jupyter pod
echo "📤 Installing runtime configuration in Jupyter..."
kubectl exec -n jupyter "$JUPYTER_POD" -- mkdir -p /home/jovyan/.local/share/jupyter/metadata/runtimes
kubectl cp /tmp/kubeflow-pipelines.json jupyter/"$JUPYTER_POD":/home/jovyan/.local/share/jupyter/metadata/runtimes/kubeflow-pipelines.json

# Clean up
rm /tmp/kubeflow-pipelines.json

echo "✅ Elyra KFP runtime configured successfully!"
echo ""
echo "📋 Runtime Configuration:"
echo "  Name: Kubeflow Pipelines"
echo "  API Endpoint: http://ml-pipeline.kubeflow:8888"
echo "  Storage: MinIO (S3-compatible)"
echo "  Authentication: None"
echo ""
