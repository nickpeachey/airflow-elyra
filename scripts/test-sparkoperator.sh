#!/bin/bash
set -e

echo "🧪 Testing SparkOperator setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if cluster exists
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}No Kubernetes cluster found. Please run ./scripts/create-cluster.sh and ./scripts/deploy-all.sh first.${NC}"
    exit 1
fi

echo -e "${YELLOW}🔍 Checking infrastructure components...${NC}"

# Check Airflow
echo "Checking Airflow..."
kubectl get pods -n airflow -l component=scheduler | grep Running || (echo -e "${RED}Airflow scheduler not running${NC}" && exit 1)
kubectl get pods -n airflow -l component=webserver | grep Running || (echo -e "${RED}Airflow webserver not running${NC}" && exit 1)

# Check SparkOperator
echo "Checking SparkOperator..."
kubectl get pods -n spark | grep spark-operator | grep Running || (echo -e "${RED}SparkOperator not running${NC}" && exit 1)

# Check LocalStack
echo "Checking LocalStack..."
kubectl get pods -n localstack -l app=localstack | grep Running || (echo -e "${RED}LocalStack not running${NC}" && exit 1)

# Check S3 buckets
echo "Checking S3 buckets..."
kubectl exec -n localstack deployment/localstack -- awslocal s3 ls s3://data-engineering-bucket/input/ | grep sales_data.csv || \
(echo -e "${RED}Test data not found in S3${NC}" && exit 1)

# Check working DAGs
echo "Checking working DAGs..."
SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}')

# Show DAG status (configured by deploy script)
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags list

echo -e "${GREEN}✅ All components are ready!${NC}"

echo -e "${YELLOW}🚀 Triggering Simple PySpark S3 DAG test (Python-based processing)...${NC}"
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags trigger simple_pyspark_s3_pipeline

echo ""
echo -e "${GREEN}🎉 Test completed! Monitor with:${NC}"
echo "• Airflow UI: http://localhost:8080"
echo "• Check S3 results: kubectl exec -n localstack deployment/localstack -- awslocal s3 ls s3://data-engineering-bucket/ --recursive"
echo ""
echo -e "${YELLOW}Expected results:${NC}"
echo "• DAG should complete successfully"
echo "• Data processing results saved to S3 buckets"
echo ""
echo -e "${YELLOW}Note: This test uses Python-based processing (not SparkOperator) due to kubectl permission limitations in Airflow pods.${NC}"
echo -e "${YELLOW}For true SparkOperator usage, SparkKubernetesOperator should be used instead of subprocess calls.${NC}"
