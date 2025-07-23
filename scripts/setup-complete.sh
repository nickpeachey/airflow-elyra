#!/bin/bash

# Complete Setup Script for Data Engineering Stack
# This script sets up the entire environment from scratch

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting complete data engineering stack setup...${NC}"
echo ""

# Step 1: Install prerequisites
echo -e "${YELLOW}Step 1: Installing prerequisites...${NC}"
if ! ./scripts/install-prerequisites.sh; then
    echo -e "${RED}❌ Failed to install prerequisites${NC}"
    exit 1
fi
echo ""

# Step 2: Create cluster
echo -e "${YELLOW}Step 2: Creating Kubernetes cluster...${NC}"
if ! ./scripts/create-cluster.sh; then
    echo -e "${RED}❌ Failed to create cluster${NC}"
    exit 1
fi
echo ""

# Step 3: Deploy all services
echo -e "${YELLOW}Step 3: Deploying all services...${NC}"
if ! ./scripts/deploy-all.sh; then
    echo -e "${RED}❌ Failed to deploy services${NC}"
    exit 1
fi
echo ""

# Step 4: Start port forwarding
echo -e "${YELLOW}Step 4: Starting port forwarding...${NC}"
# Kill any existing port forwarding
pkill -f "kubectl port-forward" || true
sleep 2

# Start port forwarding in background
kubectl port-forward -n airflow svc/airflow-webserver 8080:8080 &
AIRFLOW_PF_PID=$!
kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888 &
JUPYTER_PF_PID=$!

echo "Port forwarding started (PIDs: $AIRFLOW_PF_PID, $JUPYTER_PF_PID)"
sleep 3
echo ""

# Final status
echo -e "${GREEN}🎉 Complete setup finished successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Stack Summary:${NC}"
echo "✅ Kubernetes cluster (kind) - Running"
echo "✅ Apache Airflow 2.10.5 - Running"
echo "✅ Jupyter Lab with Elyra - Running" 
echo "✅ Spark Operator (Kubeflow) - Running"
echo "✅ LocalStack (AWS emulation) - Running"
echo "✅ DAGs deployed and visible"
echo "✅ Notebooks deployed"
echo ""
echo -e "${YELLOW}🌐 Access URLs:${NC}"
echo "• Airflow UI: http://localhost:8080 (admin/admin)"
echo "• Jupyter Lab: http://localhost:8888"
echo "• LocalStack: http://localhost:4566"
echo ""
echo -e "${YELLOW}🛠️ Useful Commands:${NC}"
echo "• Get Jupyter token: kubectl logs -n jupyter deployment/jupyter-lab | grep -E 'token=|/?token='"
echo "• Redeploy content: ./scripts/deploy-content.sh"
echo "• View DAGs: kubectl exec -n airflow airflow-scheduler-0 -c scheduler -- airflow dags list"
echo "• Cleanup everything: ./scripts/cleanup.sh"
echo ""
echo -e "${GREEN}Happy data engineering! 🎯${NC}"
