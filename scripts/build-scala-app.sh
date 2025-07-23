#!/bin/bash
set -e

echo "🔨 Building and deploying Scala Spark application..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SPARK_APP_DIR="$PROJECT_ROOT/spark-apps"

# Check if SBT is installed
if ! command -v sbt &> /dev/null; then
    echo -e "${YELLOW}Installing SBT...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install sbt
    else
        echo -e "${RED}Please install SBT manually for your operating system${NC}"
        exit 1
    fi
fi

# Build the Scala application
echo -e "${YELLOW}Building Scala Spark application...${NC}"
cd "$SPARK_APP_DIR"

# Create assembly JAR
sbt clean assembly

# Check if JAR was created
JAR_FILE=$(find target/scala-2.12 -name "*.jar" | grep -v "original" | head -1)
if [ -z "$JAR_FILE" ]; then
    echo -e "${RED}❌ JAR file not found after build${NC}"
    exit 1
fi

echo -e "${GREEN}✅ JAR built successfully: $JAR_FILE${NC}"

# Upload JAR to LocalStack S3
echo -e "${YELLOW}Uploading JAR to LocalStack S3...${NC}"

# Port forward LocalStack if needed
LOCALSTACK_PORT=$(kubectl get svc -n localstack localstack-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")

if [ -z "$LOCALSTACK_PORT" ]; then
    echo -e "${YELLOW}Starting port-forward to LocalStack...${NC}"
    kubectl port-forward -n localstack svc/localstack-service 4566:4566 &
    PORT_FORWARD_PID=$!
    sleep 5
    ENDPOINT_URL="http://localhost:4566"
else
    ENDPOINT_URL="http://localhost:$LOCALSTACK_PORT"
fi

# Set AWS credentials for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Create bucket and upload JAR
aws --endpoint-url="$ENDPOINT_URL" s3 mb s3://data-lake || true
aws --endpoint-url="$ENDPOINT_URL" s3 cp "$JAR_FILE" s3://data-lake/spark-jobs/data-processing_2.12-1.0.jar

echo -e "${GREEN}✅ JAR uploaded to S3${NC}"

# Clean up port-forward if we started it
if [ ! -z "$PORT_FORWARD_PID" ]; then
    kill $PORT_FORWARD_PID 2>/dev/null || true
fi

# Deploy Spark applications
echo -e "${YELLOW}Deploying Spark applications...${NC}"
kubectl apply -f "$PROJECT_ROOT/spark-apps/scala-spark-apps.yaml"

echo -e "${GREEN}🎉 Scala Spark application deployed successfully!${NC}"
echo -e "${YELLOW}You can now:${NC}"
echo "• Run the Scala Spark Pipeline DAG in Airflow"
echo "• Submit Spark jobs directly: kubectl apply -f spark-apps/scala-spark-apps.yaml"
echo "• Monitor jobs: kubectl get sparkapplication -n spark"
echo "• View logs: kubectl logs -n spark -l spark-role=driver"
