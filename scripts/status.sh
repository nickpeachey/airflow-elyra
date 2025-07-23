#!/bin/bash
set -e

echo "📊 Getting status of all services..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Cluster Info ===${NC}"
if kubectl cluster-info &> /dev/null; then
    kubectl cluster-info --context kind-data-engineering-stack
else
    echo -e "${RED}❌ No cluster found${NC}"
    exit 1
fi

echo -e "\n${YELLOW}=== Namespace Status ===${NC}"
kubectl get namespaces

echo -e "\n${YELLOW}=== Pod Status ===${NC}"
kubectl get pods --all-namespaces -o wide

echo -e "\n${YELLOW}=== Service Status ===${NC}"
kubectl get svc --all-namespaces

echo -e "\n${YELLOW}=== PVC Status ===${NC}"
kubectl get pvc --all-namespaces

echo -e "\n${YELLOW}=== Ingress Status ===${NC}"
kubectl get ingress --all-namespaces

echo -e "\n${YELLOW}=== Access URLs ===${NC}"
echo "🌐 Airflow UI: http://localhost:8080 (admin/admin)"
echo "📓 Jupyter Lab: http://localhost:8888 (token: datascience123)"
echo "☁️  LocalStack: http://localhost:4566"

echo -e "\n${YELLOW}=== Useful Commands ===${NC}"
echo "📋 Get Jupyter token: kubectl logs -n jupyter deployment/jupyter-lab | grep -E 'token=|/?token='"
echo "🔍 Port forward Airflow: kubectl port-forward -n airflow svc/airflow-webserver 8080:8080"
echo "🔍 Port forward Jupyter: kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888"
echo "🔍 Port forward LocalStack: kubectl port-forward -n localstack svc/localstack-service 4566:4566"
echo "📊 View logs: kubectl logs -n <namespace> <pod-name> -f"
