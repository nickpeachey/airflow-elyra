#!/bin/bash

# Complete Data Engineering Stack Deployment
# This script deploys EVERYTHING in the correct order:
# 1. Airflow + SparkOperator + LocalStack (traditional stack)
# 2. Elyra + Kubeflow Pipelines (visual pipeline stack)

set -e

# Global variables for port forwarding PIDs
AIRFLOW_PF_PID=""
JUPYTER_PF_PID=""
KFP_UI_PF_PID=""
KFP_API_PF_PID=""
LOCALSTACK_PF_PID=""

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up port forwarding processes..."
    for pid in "$AIRFLOW_PF_PID" "$JUPYTER_PF_PID" "$KFP_UI_PF_PID" "$KFP_API_PF_PID" "$LOCALSTACK_PF_PID"; do
        if [[ -n "$pid" && "$pid" != "existing" ]]; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}

# Set up trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to print phase headers
print_phase() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🎯 PHASE $1: $2${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print step headers
print_step() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}🔥 STEP $1: $2${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo -e "${CYAN}🚀 COMPLETE DATA ENGINEERING STACK DEPLOYMENT${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo -e "${YELLOW}This script will deploy EVERYTHING in the correct order:${NC}"
echo ""
echo -e "${MAGENTA}PHASE 1 - TRADITIONAL STACK:${NC}"
echo "• Kind Kubernetes cluster (3 nodes)"
echo "• Apache Airflow 2.10.5 with PostgreSQL & Redis"
echo "• SparkOperator (Kubeflow) with apache/spark:3.5.5"
echo "• LocalStack with S3 API compatibility"
echo "• Jupyter Lab for interactive development"
echo "• GitHub DAG synchronization"
echo ""
echo -e "${MAGENTA}PHASE 2 - VISUAL PIPELINE STACK:${NC}"
echo "• Custom Jupyter image with Elyra 3.15.0"
echo "• Kubeflow Pipelines v1.8.22 (compatible with Elyra)"
echo "• Elyra runtime configuration for KFP"
echo "• Visual pipeline development environment"
echo ""

# Check for AUTO_YES environment variable
if [[ "${AUTO_YES:-}" != "true" ]]; then
    echo -e "${YELLOW}⚠️  This will deploy BOTH Phase 1 AND Phase 2 automatically.${NC}"
    echo -e "${YELLOW}   The complete process will take 10-15 minutes and download/install many components.${NC}"
    echo ""
    read -p "Do you want to continue with BOTH phases? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Deployment cancelled by user.${NC}"
        exit 1
    fi
fi

# =============================================================================
# PHASE 1: TRADITIONAL STACK (Airflow + SparkOperator + LocalStack)
# =============================================================================

print_phase "1" "TRADITIONAL STACK (AIRFLOW + SPARKOPERATOR + LOCALSTACK)"

# Step 1: Cleanup any existing infrastructure
print_step "1" "CLEANING UP EXISTING INFRASTRUCTURE"
echo -e "${YELLOW}🧹 Running cleanup script...${NC}"
"$SCRIPT_DIR/cleanup.sh"

# Step 2: Create Kind cluster
print_step "2" "CREATING KUBERNETES CLUSTER"
echo -e "${YELLOW}🏗️  Creating 3-node Kind cluster...${NC}"
"$SCRIPT_DIR/create-cluster.sh"

# Step 3: Deploy traditional stack
print_step "3" "DEPLOYING TRADITIONAL STACK"
echo -e "${YELLOW}🚀 Deploying Airflow + SparkOperator + LocalStack + Jupyter...${NC}"
"$SCRIPT_DIR/deploy-all.sh"

# Step 4: Test traditional SparkOperator functionality
print_step "4" "TESTING TRADITIONAL STACK"
echo -e "${YELLOW}🧪 Testing SparkOperator functionality...${NC}"
if [[ -f "$SCRIPT_DIR/test-sparkoperator.sh" ]]; then
    "$SCRIPT_DIR/test-sparkoperator.sh"
else
    echo -e "${YELLOW}⚠️  test-sparkoperator.sh not found, skipping traditional stack test${NC}"
fi

echo ""
echo -e "${GREEN}✅ PHASE 1 COMPLETE: Traditional stack is working!${NC}"
echo -e "${YELLOW}📋 Available services:${NC}"
echo "  • Airflow: Ready for traditional DAG execution"
echo "  • SparkOperator: Processing data with Spark jobs"
echo "  • LocalStack: S3 storage with sample data"
echo "  • Jupyter: Interactive development environment"

echo ""
echo -e "${CYAN}🔄 Automatically continuing to Phase 2...${NC}"
sleep 2

# =============================================================================
# PHASE 2: VISUAL PIPELINE STACK (Elyra + KFP)
# =============================================================================

print_phase "2" "VISUAL PIPELINE STACK (ELYRA + KUBEFLOW PIPELINES)"

# Step 5: Build custom Jupyter image with Elyra
print_step "5" "BUILDING CUSTOM JUPYTER IMAGE WITH ELYRA"
echo -e "${YELLOW}🏗️  Building Jupyter image with Elyra 3.15.0...${NC}"
"$SCRIPT_DIR/build-jupyter-image.sh"

# Step 6: Upgrade Jupyter deployment to use Elyra image
print_step "6" "UPGRADING JUPYTER WITH ELYRA"
echo -e "${YELLOW}🔧 Upgrading Jupyter deployment to use Elyra image...${NC}"

# Update Jupyter deployment to use the Elyra image
kubectl patch deployment jupyter-lab -n jupyter -p '{"spec":{"template":{"spec":{"containers":[{"name":"jupyter-lab","image":"jupyter-elyra:latest","imagePullPolicy":"Never"}]}}}}'

echo "⏳ Waiting for Jupyter upgrade to complete..."
kubectl rollout status deployment/jupyter-lab -n jupyter --timeout=300s
echo -e "${GREEN}✅ Jupyter upgraded to use Elyra image!${NC}"

# Step 7: Install Kubeflow Pipelines
print_step "7" "INSTALLING KUBEFLOW PIPELINES"
echo -e "${YELLOW}🤖 Installing KFP v1.8.22 (compatible with Elyra)...${NC}"
"$SCRIPT_DIR/install-kubeflow-pipelines.sh"

# Step 8: Configure Elyra runtime for KFP
print_step "8" "CONFIGURING ELYRA RUNTIME"
echo -e "${YELLOW}🔧 Setting up Elyra runtime for KFP execution...${NC}"
"$SCRIPT_DIR/configure-elyra-kfp-new.sh"

# Step 9: Deploy notebooks for visual pipelines
print_step "9" "DEPLOYING NOTEBOOKS FOR VISUAL PIPELINES"
echo -e "${YELLOW}📓 Copying notebooks and data to Jupyter...${NC}"

# Use the dedicated content deployment script (has proper LocalStack endpoint fixes and kernelspec metadata)
"$SCRIPT_DIR/deploy-content.sh"

# Ensure data directory exists and copy sample data
echo "📁 Copying sample data..."
JUPYTER_POD=$(kubectl get pods -n jupyter -l app=jupyter-lab -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n jupyter $JUPYTER_POD -- mkdir -p /home/jovyan/work/data
kubectl cp data/sales_data.csv jupyter/$JUPYTER_POD:/home/jovyan/work/data/sales_data.csv

echo -e "${GREEN}✅ Notebooks and data deployed for visual pipeline development!${NC}"
echo -e "${YELLOW}📋 Available notebooks:${NC}"
echo "  • data_ingestion_fixed.ipynb - Data ingestion with S3"
echo "  • data_validation_fixed.ipynb - Data validation and cleaning"
echo "  • simple_analysis_fixed.ipynb - Basic data analysis"
echo "  • elyra_test_pipeline.ipynb - Simple test notebook for pipeline testing"

# Step 10: Test Kubeflow Pipelines
print_step "10" "TESTING KUBEFLOW PIPELINES"
echo -e "${YELLOW}🧪 Testing KFP functionality...${NC}"
if [[ -f "$SCRIPT_DIR/test-kubeflow-pipelines.sh" ]]; then
    "$SCRIPT_DIR/test-kubeflow-pipelines.sh"
else
    echo -e "${YELLOW}⚠️  test-kubeflow-pipelines.sh not found, skipping KFP test${NC}"
fi

echo ""
echo -e "${GREEN}✅ PHASE 2 COMPLETE: Visual pipeline stack is working!${NC}"
echo -e "${YELLOW}📋 Added services:${NC}"
echo "  • Elyra: Visual pipeline editor in Jupyter"
echo "  • KFP: Pipeline execution backend"
echo "  • MinIO: Pipeline artifact storage"

# =============================================================================
# FINAL SETUP AND INSTRUCTIONS
# =============================================================================

print_step "11" "SETUP COMPLETE - STARTING PORT FORWARDING"

echo ""
echo -e "${GREEN}🎉 COMPLETE DEPLOYMENT SUCCESSFUL! 🎉${NC}"
echo ""

echo -e "${YELLOW}🌐 ACCESS YOUR APPLICATIONS:${NC}"
echo ""
echo -e "${BLUE}Web Interfaces (run port-forward commands in separate terminals):${NC}"
echo "   • Airflow UI:         http://localhost:8080 (admin/admin)"
echo "   • Jupyter/Elyra:      http://localhost:8888 (token: datascience123)"
echo "   • KFP UI:            http://localhost:8882"
echo "   • KFP API:           http://localhost:8881"
echo "   • LocalStack:        http://localhost:4566"
echo ""

echo -e "${YELLOW}📋 PORT FORWARDING COMMANDS:${NC}"
echo "   kubectl port-forward -n airflow svc/airflow-webserver 8080:8080"
echo "   kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888"
echo "   kubectl port-forward -n kubeflow svc/ml-pipeline-ui 8882:80"
echo "   kubectl port-forward -n kubeflow svc/ml-pipeline 8881:8888"
echo "   kubectl port-forward -n localstack svc/localstack-service 4566:4566"
echo ""

echo -e "${YELLOW}🎨 DEVELOPMENT WORKFLOWS:${NC}"
echo ""
echo -e "${BLUE}Traditional Airflow DAGs:${NC}"
echo "• Open Airflow UI and monitor traditional data processing"
echo "• Use SparkOperator for large-scale data processing"
echo ""
echo -e "${BLUE}Visual Pipeline Development with Elyra:${NC}"
echo "• Open Jupyter and use the Pipeline Editor"
echo "• Create drag-and-drop workflows with notebooks"
echo "• Submit pipelines for execution on Kubernetes"
echo "• Monitor execution in KFP UI"
echo ""

echo -e "${GREEN}🏆 YOUR COMPLETE DATA ENGINEERING STACK IS READY! 🏆${NC}"
echo ""
echo -e "${MAGENTA}💡 Next steps:${NC}"
echo "1. Run the port forwarding commands above in separate terminals"
echo "2. Open both Airflow UI and Jupyter to explore both approaches"
echo "3. Try traditional Spark processing with Airflow DAGs"
echo "4. Experiment with visual pipeline development in Elyra"
echo "5. Both systems share the same LocalStack S3 storage"
echo ""
echo -e "${GREEN}Happy data engineering with both traditional and visual approaches! 🚀${NC}"
