#!/bin/bash
set -e

echo "🚀 Deploying all services to the cluster..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if cluster exists
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}No Kubernetes cluster found. Please run ./scripts/create-cluster.sh first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Deploying RBAC resources...${NC}"
kubectl apply -f "$PROJECT_ROOT/k8s/airflow/airflow-rbac.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/spark/spark-rbac.yaml"

echo -e "${YELLOW}Deploying Airflow with built-in PostgreSQL and Redis...${NC}"
helm upgrade --install airflow apache-airflow/airflow --version 1.16.0 \
    --namespace airflow \
    --values "$PROJECT_ROOT/helm/airflow-values-simple.yaml" \
    --timeout=15m

echo -e "${YELLOW}Deploying Spark Operator (Kubeflow)...${NC}"
helm upgrade --install spark-operator spark-operator/spark-operator  \
    --namespace spark \
    --wait

echo -e "${YELLOW}Deploying Jupyter Lab...${NC}"
kubectl apply -f "$PROJECT_ROOT/k8s/jupyter/"

echo -e "${YELLOW}Deploying LocalStack...${NC}"
kubectl apply -f "$PROJECT_ROOT/k8s/localstack/"

echo -e "${YELLOW}Waiting for all deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=600s deployment --all -n airflow
kubectl wait --for=condition=available --timeout=300s deployment --all -n jupyter
kubectl wait --for=condition=available --timeout=300s deployment --all -n localstack

echo -e "${GREEN}🎉 All services deployed successfully!${NC}"

# Setup SparkOperator RBAC and ConfigMaps
echo -e "${YELLOW}🔧 Setting up SparkOperator configuration...${NC}"
kubectl create serviceaccount spark-operator-spark --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding spark-operator-spark --clusterrole=edit --serviceaccount=default:spark-operator-spark --dry-run=client -o yaml | kubectl apply -f -

# Create ConfigMap with Spark job code
echo -e "${YELLOW}📦 Creating ConfigMap with Spark job code...${NC}"
kubectl create configmap spark-job-code --from-file="$PROJECT_ROOT/spark-apps/spark_s3_job.py" --dry-run=client -o yaml | kubectl apply -f -

# Setup LocalStack S3 buckets and test data
echo -e "${YELLOW}🪣 Setting up LocalStack S3 buckets and test data...${NC}"
# Wait for LocalStack to be ready
kubectl wait --for=condition=available --timeout=300s deployment/localstack -n localstack

# Create S3 buckets
kubectl exec -n localstack deployment/localstack -- awslocal s3 mb s3://data-engineering-bucket || echo "Bucket may already exist"
kubectl exec -n localstack deployment/localstack -- awslocal s3 mb s3://airflow-logs || echo "Bucket may already exist"

# Upload test data
echo -e "${YELLOW}📊 Uploading test sales data...${NC}"
kubectl cp "$PROJECT_ROOT/data/sales_data.csv" localstack/$(kubectl get pods -n localstack -l app=localstack -o jsonpath='{.items[0].metadata.name}'):/tmp/sales_data.csv
kubectl exec -n localstack deployment/localstack -- awslocal s3 cp /tmp/sales_data.csv s3://data-engineering-bucket/input/sales_data.csv

# Deploy DAGs and notebooks
echo -e "${YELLOW}📋 Deploying DAGs and notebooks...${NC}"
"$PROJECT_ROOT/scripts/deploy-content.sh"

# Deploy SparkOperator specific DAGs
echo -e "${YELLOW}⚡ Deploying SparkOperator DAGs...${NC}"
# Wait for Airflow pods to be ready
kubectl wait --for=condition=ready --timeout=600s pod -l component=scheduler -n airflow
kubectl wait --for=condition=ready --timeout=600s pod -l component=webserver -n airflow

# Get pod names
SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}')
WEBSERVER_POD=$(kubectl get pods -n airflow -l component=webserver -o jsonpath='{.items[0].metadata.name}')

# Copy SparkOperator DAGs
kubectl cp "$PROJECT_ROOT/dags/spark_operator_s3.py" airflow/$SCHEDULER_POD:/opt/airflow/dags/ -c scheduler
kubectl cp "$PROJECT_ROOT/dags/spark_application.yaml" airflow/$SCHEDULER_POD:/opt/airflow/dags/ -c scheduler

# Refresh DAGs in Airflow
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags reserialize

# Unpause the SparkOperator DAG
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags unpause spark_operator_s3_pipeline || echo "DAG may not be loaded yet"

echo ""
echo -e "${GREEN}🎉 Complete setup finished!${NC}"
echo -e "${GREEN}✅ SparkOperator with S3 integration is ready!${NC}"
echo ""
echo -e "${YELLOW}🚀 Infrastructure deployed:${NC}"
echo "• Apache Airflow 2.10.5 with PostgreSQL and Redis"
echo "• SparkOperator (Kubeflow) with apache/spark:3.5.5"
echo "• Jupyter Lab for interactive development"
echo "• LocalStack with S3 buckets and test data"
echo "• Complete RBAC configuration for SparkOperator"
echo ""
echo -e "${YELLOW}Access URLs:${NC}"
echo "• Airflow UI: http://localhost:8080 (admin/admin)"
echo "• Jupyter Lab: http://localhost:8888 (check logs for token)"
echo "• LocalStack: http://localhost:4566"
echo ""
echo -e "${YELLOW}🚀 Ready to use:${NC}"
echo "• SparkOperator DAG: spark_operator_s3_pipeline (authentic SparkKubernetesOperator)"
echo "• S3 test data: s3://data-engineering-bucket/input/sales_data.csv"
echo "• Apache Spark 3.5.5 with complete S3 integration"
echo ""
echo -e "${YELLOW}Quick test:${NC}"
echo "• ./scripts/test-sparkoperator.sh"
echo ""
echo -e "${YELLOW}Manual operations:${NC}"
echo "• kubectl exec -n airflow <scheduler-pod> -c scheduler -- airflow dags trigger spark_operator_s3_pipeline"
echo "• kubectl get sparkapplications (to monitor Spark jobs)"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "• Get Jupyter token: kubectl logs -n jupyter deployment/jupyter-lab | grep -E 'token=|/?token='"
echo "• Start port forwarding: kubectl port-forward -n airflow svc/airflow-webserver 8080:8080 & kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888 &"
echo "• Redeploy content: $PROJECT_ROOT/scripts/deploy-content.sh"
echo "• View all pods: kubectl get pods --all-namespaces"
echo "• Check SparkApplications: kubectl get sparkapplications"
echo ""
echo -e "${GREEN}🎯 Next steps:${NC}"
echo "1. Run port forwarding to access UIs"
echo "2. Open Airflow UI at http://localhost:8080"
echo "3. The spark_operator_s3_pipeline DAG is ready to use!"
echo "4. Run ./scripts/test-sparkoperator.sh to verify everything works"
