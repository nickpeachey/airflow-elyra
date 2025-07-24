#!/bin/bash
set -e

echo "🔗 Setting up Airflow connections for GitHub DAG sync..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Wait for Airflow to be ready
echo -e "${YELLOW}⏳ Waiting for Airflow scheduler to be ready...${NC}"
kubectl wait --for=condition=ready --timeout=600s pod -l component=scheduler -n airflow

SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}')

echo -e "${YELLOW}📡 Creating S3 connection for LocalStack...${NC}"
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow connections add 's3_default' \
    --conn-type 'aws' \
    --conn-login 'test' \
    --conn-password 'test' \
    --conn-extra '{"aws_access_key_id": "test", "aws_secret_access_key": "test", "endpoint_url": "http://localstack-service.localstack.svc.cluster.local:4566", "region_name": "us-east-1"}' || echo "Connection may already exist"

echo -e "${YELLOW}☸️  Creating Kubernetes connection...${NC}"
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow connections add 'kubernetes_default' \
    --conn-type 'kubernetes' \
    --conn-extra '{"in_cluster": true, "namespace": "default"}' || echo "Connection may already exist"

echo -e "${YELLOW}🔄 Testing S3 connection...${NC}"
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow connections test s3_default || echo "Connection test may fail until LocalStack is fully ready"

echo -e "${GREEN}✅ Airflow connections configured successfully!${NC}"

echo ""
echo -e "${YELLOW}📋 Available connections:${NC}"
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow connections list

echo ""
echo -e "${GREEN}🎉 Git sync setup complete! DAGs will be automatically pulled from GitHub.${NC}"
