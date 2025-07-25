#!/bin/bash
set -e

# Test Elyra Pipeline Submission to Real KFP
# This script demonstrates how to submit and monitor a pipeline in Elyra

echo "🎨 Testing Elyra Pipeline with Real Kubeflow Pipelines..."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if required components are ready
echo "🔍 Checking prerequisites..."

# Check if KFP is ready
if ! curl -s --connect-timeout 5 http://localhost:30888/apis/v1beta1/healthz > /dev/null; then
    echo -e "${RED}❌ Kubeflow Pipelines API is not accessible${NC}"
    echo "Make sure KFP is running: kubectl get pods -n kubeflow"
    exit 1
fi

# Check if Jupyter is accessible
JUPYTER_POD=$(kubectl get pods -n jupyter -l app=jupyter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$JUPYTER_POD" ]; then
    echo -e "${RED}❌ Jupyter pod not found${NC}"
    echo "Make sure Jupyter is running: kubectl get pods -n jupyter"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Create a simple test pipeline file
echo "📝 Creating a test pipeline configuration..."

# Create a minimal pipeline for testing
cat > /tmp/test-elyra-pipeline.py << 'EOF'
# Simple test pipeline for Elyra
import os
import time

print("🚀 Starting Elyra test pipeline execution...")
print(f"Current time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
print(f"Working directory: {os.getcwd()}")
print(f"Environment variables:")
for key, value in os.environ.items():
    if key.startswith(('AWS_', 'S3_', 'JUPYTER_')):
        print(f"  {key}: {value}")

# Test S3 connectivity
try:
    import boto3
    from botocore.config import Config
    
    # Configure S3 client for LocalStack
    s3_client = boto3.client(
        's3',
        endpoint_url='http://localstack-service.localstack:4566',
        aws_access_key_id='test',
        aws_secret_access_key='test123',
        region_name='us-east-1',
        config=Config(signature_version='s3v4')
    )
    
    # List buckets
    response = s3_client.list_buckets()
    print(f"📦 Available S3 buckets: {[bucket['Name'] for bucket in response['Buckets']]}")
    
    # Test write to bucket
    test_key = f"test-pipeline-{int(time.time())}.txt"
    s3_client.put_object(
        Bucket='airflow-logs',
        Key=test_key,
        Body=f"Test pipeline execution at {time.strftime('%Y-%m-%d %H:%M:%S')}"
    )
    print(f"✅ Successfully wrote test file: s3://airflow-logs/{test_key}")
    
except Exception as e:
    print(f"⚠️  S3 test failed: {str(e)}")

print("✅ Elyra test pipeline completed successfully!")
EOF

# Copy the test file to Jupyter
echo "📤 Copying test pipeline to Jupyter..."
kubectl cp /tmp/test-elyra-pipeline.py jupyter/$JUPYTER_POD:/tmp/test-elyra-pipeline.py

echo ""
echo -e "${GREEN}🎉 Elyra Pipeline Test Setup Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Manual Testing Steps:${NC}"
echo ""
echo "1. Open Jupyter/Elyra at: http://localhost:8889"
echo ""
echo "2. Get Jupyter token:"
echo "   kubectl logs -n jupyter $JUPYTER_POD | grep 'token=' | tail -1"
echo ""
echo "3. Create a new pipeline:"
echo "   • Click the 'Pipeline Editor' icon in the launcher"
echo "   • Drag a 'Python Script' node onto the canvas"
echo "   • Configure the node:"
echo "     - Script file: /tmp/test-elyra-pipeline.py"
echo "     - Runtime image: jupyter-elyra:latest"
echo ""
echo "4. Submit the pipeline:"
echo "   • Click the 'Run Pipeline' button (▶️)"
echo "   • Select runtime: 'Kubeflow Pipelines (Real)'"
echo "   • Provide a pipeline name: 'test-elyra-kfp'"
echo "   • Click 'OK'"
echo ""
echo "5. Monitor execution:"
echo "   • KFP UI: http://localhost:30080"
echo "   • Check pipeline runs in the Experiments section"
echo "   • View logs and artifacts"
echo ""
echo "6. Verify results:"
echo "   • Check S3 for test artifacts:"
echo "     kubectl exec -n localstack deployment/localstack -- awslocal s3 ls s3://airflow-logs/"
echo ""

# Show current KFP status
echo -e "${YELLOW}📊 Current KFP Status:${NC}"
kubectl get pods -n kubeflow | head -10
echo ""

echo -e "${YELLOW}🔗 Useful URLs:${NC}"
echo "   • Jupyter/Elyra:      http://localhost:8889"
echo "   • KFP UI:            http://localhost:30080"
echo "   • KFP API:           http://localhost:30888"
echo ""

echo -e "${GREEN}✨ Ready for visual pipeline development with Elyra!${NC}"
