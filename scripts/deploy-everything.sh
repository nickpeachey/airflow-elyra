#!/bin/bash
set -e

# Master deployment script for the complete data engineering stack
# This is the ONLY script you need to run to get everything working

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

# Handle help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "🚀 COMPLETE DATA ENGINEERING STACK DEPLOYMENT"
    echo "=============================================="
    echo ""
    echo "USAGE:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "ENVIRONMENT VARIABLES:"
    echo "  AUTO_YES=true  Skip interactive confirmations"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                    # Interactive deployment"
    echo "  AUTO_YES=true $0      # Automated deployment"
    echo ""
    echo "WHAT THIS SCRIPT DOES:"
    echo "  1. Checks prerequisites (kind, kubectl, helm, docker)"
    echo "  2. Cleans up any existing infrastructure"
    echo "  3. Creates a 3-node kind Kubernetes cluster"
    echo "  4. Deploys all services (Airflow, SparkOperator, Jupyter, LocalStack)"
    echo "  5. Sets up S3 buckets and sample data"
    echo "  6. Configures authentic SparkOperator with S3 integration"
    echo "  7. Tests the complete pipeline"
    echo ""
    echo "RESULT:"
    echo "  Complete working data engineering stack with:"
    echo "  • Apache Airflow 2.10.5"
    echo "  • SparkOperator with apache/spark:3.5.5"
    echo "  • Jupyter Lab"
    echo "  • LocalStack S3"
    echo "  • Working analytics pipeline"
    echo ""
    echo "For more information, see: ONE_COMMAND_SETUP.md"
    exit 0
fi

echo -e "${CYAN}🚀 COMPLETE DATA ENGINEERING STACK DEPLOYMENT${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo -e "${YELLOW}This script will deploy:${NC}"
echo "• Kind Kubernetes cluster (3 nodes)"
echo "• Apache Airflow 2.10.5 with PostgreSQL & Redis"
echo "• SparkOperator (Kubeflow) with apache/spark:3.5.5"
echo "• Jupyter Lab for interactive development"
echo "• LocalStack with S3 API compatibility"
echo "• Complete SparkOperator S3 integration"
echo "• Sample data and working analytics pipeline"
echo ""

# Function to print step headers
print_step() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}🔥 STEP $1: $2${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to check if user wants to continue
confirm_step() {
    if [[ "${AUTO_YES:-}" != "true" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  This will take several minutes and download/install many components.${NC}"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}❌ Deployment cancelled by user.${NC}"
            exit 1
        fi
    fi
}

# Check prerequisites
print_step "1" "CHECKING PREREQUISITES"
echo -e "${YELLOW}🔍 Checking required tools...${NC}"

# Check for required tools
MISSING_TOOLS=()

if ! command -v kind &> /dev/null; then
    MISSING_TOOLS+=("kind")
fi

if ! command -v kubectl &> /dev/null; then
    MISSING_TOOLS+=("kubectl")
fi

if ! command -v helm &> /dev/null; then
    MISSING_TOOLS+=("helm")
fi

if ! command -v docker &> /dev/null; then
    MISSING_TOOLS+=("docker")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing required tools: ${MISSING_TOOLS[*]}${NC}"
    echo ""
    echo -e "${YELLOW}Please install the missing tools:${NC}"
    echo "• kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    echo "• kubectl: https://kubernetes.io/docs/tasks/tools/"
    echo "• helm: https://helm.sh/docs/intro/install/"
    echo "• docker: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${GREEN}✅ All required tools are installed!${NC}"

# Check Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker is running!${NC}"

# Confirm deployment
confirm_step

# Step 2: Cleanup any existing infrastructure
print_step "2" "CLEANING UP EXISTING INFRASTRUCTURE"
echo -e "${YELLOW}🧹 Running cleanup script...${NC}"
"$SCRIPT_DIR/cleanup.sh"

# Step 3: Create Kind cluster
print_step "3" "CREATING KUBERNETES CLUSTER"
echo -e "${YELLOW}🏗️  Creating 3-node Kind cluster...${NC}"
"$SCRIPT_DIR/create-cluster.sh"

# Step 4: Deploy all services
print_step "4" "DEPLOYING ALL SERVICES"
echo -e "${YELLOW}🚀 Deploying complete data engineering stack...${NC}"
echo "   This includes: Airflow, SparkOperator, Jupyter, LocalStack, RBAC, S3 setup"
"$SCRIPT_DIR/deploy-all.sh"

# Step 5: Test the deployment
print_step "5" "TESTING SPARKOPERATOR PIPELINE"
echo -e "${YELLOW}🧪 Running comprehensive tests...${NC}"
"$SCRIPT_DIR/test-sparkoperator.sh"

# Step 6: Final setup and instructions
print_step "6" "SETUP COMPLETE!"
echo ""
echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL! 🎉${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    QUICK START GUIDE                          ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📋 WHAT'S DEPLOYED:${NC}"
echo "✅ Kind Kubernetes cluster (3 nodes)"
echo "✅ Apache Airflow 2.10.5 with PostgreSQL & Redis"
echo "✅ SparkOperator (Kubeflow) with authentic SparkKubernetesOperator"
echo "✅ Apache Spark 3.5.5 with complete S3 integration"
echo "✅ Jupyter Lab for interactive development"
echo "✅ LocalStack with S3 buckets and sample data"
echo "✅ Working analytics pipeline with real data processing"
echo ""

echo -e "${YELLOW}🌐 ACCESS YOUR APPLICATIONS:${NC}"
echo ""
echo -e "${BLUE}1. Start Port Forwarding (run in separate terminals):${NC}"
echo "   kubectl port-forward -n airflow svc/airflow-webserver 8080:8080"
echo "   kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888"
echo ""
echo -e "${BLUE}2. Open Web Interfaces:${NC}"
echo "   • Airflow UI: http://localhost:8080 (admin/admin)"
echo "   • Jupyter Lab: http://localhost:8888"
echo ""
echo -e "${BLUE}3. Get Jupyter Token:${NC}"
echo "   kubectl logs -n jupyter deployment/jupyter-lab | grep -E 'token=|/?token='"
echo ""

echo -e "${YELLOW}⚡ TEST THE SPARKOPERATOR PIPELINE:${NC}"
echo ""
echo -e "${BLUE}The SparkOperator DAG is ready to use:${NC}"
echo "• DAG Name: spark_operator_s3_pipeline"
echo "• Uses authentic SparkKubernetesOperator (not simple Kubernetes pods)"
echo "• Processes real sales data with comprehensive analytics"
echo "• Saves results to S3 buckets (regional, category, customer analysis)"
echo ""
echo -e "${BLUE}Monitor SparkApplications:${NC}"
echo "   kubectl get sparkapplications -w"
echo ""
echo -e "${BLUE}Trigger manually:${NC}"
echo "   kubectl exec -n airflow \$(kubectl get pods -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}') -c scheduler -- airflow dags trigger spark_operator_s3_pipeline"
echo ""

echo -e "${YELLOW}🔧 USEFUL COMMANDS:${NC}"
echo ""
echo -e "${BLUE}View all pods:${NC}"
echo "   kubectl get pods --all-namespaces"
echo ""
echo -e "${BLUE}Check S3 data:${NC}"
echo "   kubectl exec -n localstack deployment/localstack -- awslocal s3 ls s3://data-engineering-bucket/ --recursive"
echo ""
echo -e "${BLUE}View Spark logs:${NC}"
echo "   kubectl logs <spark-driver-pod-name>"
echo ""
echo -e "${BLUE}Redeploy DAGs/content only:${NC}"
echo "   $SCRIPT_DIR/deploy-content.sh"
echo ""
echo -e "${BLUE}Test SparkOperator again:${NC}"
echo "   $SCRIPT_DIR/test-sparkoperator.sh"
echo ""
echo -e "${BLUE}Clean up everything:${NC}"
echo "   $SCRIPT_DIR/cleanup.sh"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🏆 YOUR LOCAL DATA ENGINEERING STACK IS READY! 🏆${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${MAGENTA}💡 Next steps:${NC}"
echo "1. Run the port forwarding commands above"
echo "2. Open Airflow UI and explore the spark_operator_s3_pipeline DAG"
echo "3. The pipeline will automatically process sales data and generate analytics"
echo "4. Check the results in LocalStack S3 buckets"
echo ""
echo -e "${YELLOW}📖 For detailed documentation, see: SPARKOPERATOR_SETUP.md${NC}"
echo ""
echo -e "${GREEN}Happy data engineering! 🚀${NC}"
