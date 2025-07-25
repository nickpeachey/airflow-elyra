#!/bin/bash
set -e

# Test Kubeflow Pipelines Installation
# This script validates that KFP is properly installed and working

echo "🧪 Testing Kubeflow Pipelines installation..."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to test HTTP endpoint
test_http() {
    local url="$1"
    curl -s --connect-timeout 10 "$url" > /dev/null
}

# Function to test API endpoint with JSON response
test_api_json() {
    local url="$1"
    curl -s --connect-timeout 10 "$url" | jq . > /dev/null
}

echo "🔍 Running Kubeflow Pipelines tests..."
echo ""

# Test 1: Check if kubeflow namespace exists
run_test "Kubeflow namespace" "kubectl get namespace kubeflow"

# Test 2: Check if KFP pods are running
run_test "KFP pods running" "kubectl get pods -n kubeflow | grep -E '(ml-pipeline|mysql|minio|workflow-controller)' | grep -v '0/1\|0/2'"

# Test 3: Check if ml-pipeline service exists
run_test "ML Pipeline service" "kubectl get service ml-pipeline -n kubeflow"

# Test 4: Check if KFP API is accessible
run_test "KFP API connectivity" "test_http http://localhost:8881/apis/v1beta1/healthz"

# Test 5: Check KFP experiments endpoint
run_test "KFP experiments API" "test_api_json http://localhost:8881/apis/v1beta1/experiments"

# Test 6: Check KFP pipelines endpoint
run_test "KFP pipelines API" "test_api_json http://localhost:8881/apis/v1beta1/pipelines"

# Test 7: Check KFP runs endpoint
run_test "KFP runs API" "test_api_json http://localhost:8881/apis/v1beta1/runs"

# Test 8: Check if KFP UI is accessible
run_test "KFP UI accessibility" "test_http http://localhost:8882"

# Test 9: Check if Argo Workflow Controller is running
run_test "Argo Workflow Controller" "kubectl get pods -n kubeflow -l app=workflow-controller | grep '1/1.*Running'"

# Test 10: Check if MySQL is running (KFP database)
run_test "MySQL database" "kubectl get pods -n kubeflow -l app=mysql | grep '1/1.*Running'"

# Test 11: Check if Minio is running (KFP artifact store)
run_test "Minio object storage" "kubectl get pods -n kubeflow -l app=minio | grep '1/1.*Running'"

echo ""
echo "📊 Test Results Summary:"
echo -e "   ${GREEN}✅ Passed: $TESTS_PASSED${NC}"
echo -e "   ${RED}❌ Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All Kubeflow Pipelines tests passed!${NC}"
    echo ""
    echo -e "${BLUE}✨ KFP is ready for use:${NC}"
    echo "   • API Endpoint: http://localhost:8881"
    echo "   • Web UI: http://localhost:8882"
    echo "   • Ready for Elyra pipeline submission"
    echo ""
    
    # Show some useful information
    echo -e "${YELLOW}📋 KFP Status Overview:${NC}"
    kubectl get pods -n kubeflow -o wide
    echo ""
    
    echo -e "${YELLOW}🔗 Quick API Test:${NC}"
    echo "Health check:"
    curl -s http://localhost:8881/apis/v1beta1/healthz | jq . || echo "API response received"
    echo ""
    
    exit 0
else
    echo -e "${RED}❌ Some Kubeflow Pipelines tests failed!${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
    echo "1. Check pod status: kubectl get pods -n kubeflow"
    echo "2. Check logs: kubectl logs -n kubeflow deployment/ml-pipeline"
    echo "3. Wait a few minutes and try again"
    echo "4. Check if all KFP components are ready:"
    echo "   kubectl get deployments -n kubeflow"
    echo ""
    
    exit 1
fi
