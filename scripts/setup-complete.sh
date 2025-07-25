#!/bin/bash

# Complete Elyra + Kubeflow Pipelines Setup Script
# This script sets up everything needed for Elyra with KFP to work from fresh

set -e

echo "🚀 Complete Elyra + Kubeflow Pipelines Setup"
echo "============================================"
echo ""
echo "This script will set up:"
echo "  ✓ Kind Kubernetes cluster (3 nodes)"
echo "  ✓ Custom Jupyter Docker image with Elyra"
echo "  ✓ Kubeflow Pipelines (v1.8.22 - compatible with Elyra)"
echo "  ✓ LocalStack S3 storage deployment"
echo "  ✓ S3 buckets for data and pipeline artifacts"
echo "  ✓ Jupyter Lab deployment with Elyra"
echo "  ✓ Elyra runtime configuration"
echo "  ✓ Sample notebooks and data deployment"
echo "  ✓ Port forwarding for UI access"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed (needed for LocalStack)"
    exit 1
fi

if ! command -v kind &> /dev/null; then
    echo "❌ kind is not installed (needed for local cluster)"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    exit 1
fi

echo "✅ Prerequisites satisfied"
echo ""

# Step 1: Create Kubernetes cluster
echo "📦 Step 1: Creating Kubernetes cluster..."
./scripts/create-cluster.sh

# Step 2: Build custom Jupyter image with Elyra
echo "📦 Step 2: Building custom Jupyter image with Elyra..."
./scripts/build-jupyter-image.sh

# Step 3: Install Kubeflow Pipelines
echo "📦 Step 3: Installing Kubeflow Pipelines..."
./scripts/install-kubeflow-pipelines.sh

# Step 4: Deploy LocalStack
echo "📦 Step 4: Deploying LocalStack S3 storage..."
echo "🔧 Deploying LocalStack to cluster..."
kubectl apply -f k8s/localstack/ -n localstack
echo "⏳ Waiting for LocalStack to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/localstack -n localstack
echo "✅ LocalStack deployed!"

# Step 5: Set up LocalStack buckets
echo "📦 Step 5: Setting up LocalStack S3 buckets..."
./scripts/setup-localstack-buckets.sh

# Step 6: Deploy Jupyter with Elyra
echo "📦 Step 6: Deploying Jupyter with Elyra..."
echo "🔧 Deploying Jupyter to cluster..."
kubectl apply -f k8s/jupyter/ -n jupyter
echo "⏳ Waiting for Jupyter to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/jupyter-lab -n jupyter
echo "✅ Jupyter deployed!"

# Step 7: Configure Elyra runtime
echo "📦 Step 7: Configuring Elyra KFP runtime..."
./scripts/configure-elyra-kfp.sh

# Step 8: Validate and deploy notebooks
echo "📦 Step 8: Validating and deploying notebooks..."
./scripts/validate-notebooks.sh

# Deploy notebooks and data with proper copying
echo "📓 Copying notebooks and data to Jupyter..."
JUPYTER_POD=$(kubectl get pods -n jupyter -l app=jupyter-lab -o jsonpath='{.items[0].metadata.name}')
echo "📋 Found Jupyter pod: $JUPYTER_POD"

# Copy all notebooks
kubectl cp notebooks/ jupyter/$JUPYTER_POD:/home/jovyan/work/notebooks/

# Create data directory and copy sample data
kubectl exec -n jupyter $JUPYTER_POD -- mkdir -p /home/jovyan/work/data
kubectl cp data/sales_data.csv jupyter/$JUPYTER_POD:/home/jovyan/work/data/sales_data.csv

echo "✅ Notebooks and data deployed!"

# Step 9: Set up port forwarding
echo "📦 Step 9: Setting up port forwarding..."

# Kill any existing port forwards
pkill -f "kubectl port-forward.*kubeflow" 2>/dev/null || true
pkill -f "kubectl port-forward.*localstack" 2>/dev/null || true
pkill -f "kubectl port-forward.*jupyter" 2>/dev/null || true

sleep 2

# Start port forwarding for Elyra + KFP services
echo "🌐 Starting port forwarding..."
kubectl port-forward -n kubeflow svc/ml-pipeline 8881:8888 > /dev/null 2>&1 &
kubectl port-forward -n kubeflow svc/ml-pipeline-ui 8882:80 > /dev/null 2>&1 &
kubectl port-forward -n localstack svc/localstack-service 4566:4566 > /dev/null 2>&1 &
kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888 > /dev/null 2>&1 &

echo "⏳ Waiting for port forwards to be ready..."
sleep 5

# Test connectivity
echo "🔍 Testing connectivity..."
if curl -s http://localhost:8881/apis/v1beta1/healthz > /dev/null; then
    echo "✅ KFP API accessible"
else
    echo "⚠️  KFP API not yet accessible (may need more time)"
fi

if curl -s http://localhost:4566/health > /dev/null; then
    echo "✅ LocalStack accessible"
else
    echo "⚠️  LocalStack not yet accessible (may need more time)"
fi

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "🌐 Access URLs:"
echo "  • Jupyter Lab: http://localhost:8888"
echo "  • KFP UI: http://localhost:8882"
echo "  • KFP API: http://localhost:8881"
echo "  • LocalStack: http://localhost:4566"
echo ""
echo "� What to do next:"
echo "  1. Open Jupyter Lab at http://localhost:8888"
echo "  2. Create a new Pipeline using the Pipeline Editor"
echo "  3. Add notebooks to your pipeline (they're already deployed)"
echo "  4. Select 'Kubeflow Pipelines' as the runtime"
echo "  5. Submit your pipeline!"
echo ""
echo "🔧 Components configured:"
echo "  ✓ Kind cluster with 3 nodes (create-cluster.sh)"
echo "  ✓ Custom Jupyter image with Elyra (build-jupyter-image.sh)"
echo "  ✓ KFP 1.8.22 (compatible with Elyra client 1.8.22)"
echo "  ✓ LocalStack S3 deployment and bucket setup"
echo "  ✓ Jupyter Lab deployment with Elyra runtime"
echo "  ✓ MinIO storage for pipeline artifacts"
echo "  ✓ Notebooks with correct cluster-internal endpoints"
echo "  ✓ All required S3 buckets created"
echo "  ✓ Port forwarding for all services"
echo ""
