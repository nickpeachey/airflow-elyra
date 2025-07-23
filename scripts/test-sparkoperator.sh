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
kubectl exec -n localstack deployment/localstack -- awslocal s3 ls s3://data-engineering-bucket/input/ | grep sales_data.csv || (echo -e "${RED}Test data not found in S3${NC}" && exit 1)

# Check SparkOperator DAG
echo "Checking SparkOperator DAG..."
SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags list | grep spark_operator_s3_pipeline || (echo -e "${RED}SparkOperator DAG not found${NC}" && exit 1)

echo -e "${GREEN}✅ All components are ready!${NC}"

echo -e "${YELLOW}🚀 Triggering SparkOperator DAG test...${NC}"
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags trigger spark_operator_s3_pipeline

echo -e "${YELLOW}⏳ Waiting for SparkApplication to start...${NC}"
sleep 10

echo -e "${YELLOW}📊 Current SparkApplications:${NC}"
kubectl get sparkapplications

echo ""
echo -e "${GREEN}🎉 Test completed! Monitor with:${NC}"
echo "• kubectl get sparkapplications -w"
echo "• kubectl logs <spark-driver-pod>"
echo "• Airflow UI: http://localhost:8080"
echo ""
echo -e "${YELLOW}Expected results:${NC}"
echo "• SparkApplication should reach COMPLETED status"
echo "• Data processing results saved to S3 buckets"
echo "• Regional, category, customer, and daily analytics generated"
