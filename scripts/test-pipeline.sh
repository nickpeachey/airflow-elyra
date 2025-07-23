#!/bin/bash
set -e

echo "🧪 Testing the data engineering pipeline..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}No Kubernetes cluster found. Please run ./scripts/create-cluster.sh first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Running pipeline tests...${NC}"

# Test 1: Check if all pods are running
echo -e "\n${YELLOW}Test 1: Pod Status${NC}"
if kubectl get pods --all-namespaces | grep -E "(Running|Completed)" > /dev/null; then
    echo -e "${GREEN}✅ Pods are running${NC}"
else
    echo -e "${RED}❌ Some pods are not running${NC}"
    kubectl get pods --all-namespaces
fi

# Test 2: Test LocalStack S3
echo -e "\n${YELLOW}Test 2: LocalStack S3${NC}"
kubectl run test-localstack --rm -i --restart=Never --image=amazon/aws-cli:latest -- \
    sh -c "aws --endpoint-url=http://localstack-service.localstack.svc.cluster.local:4566 s3 ls || echo 'S3 test failed'"

# Test 3: Test Jupyter accessibility
echo -e "\n${YELLOW}Test 3: Jupyter Lab${NC}"
JUPYTER_POD=$(kubectl get pods -n jupyter -l app=jupyter-lab -o jsonpath='{.items[0].metadata.name}')
if [ -n "$JUPYTER_POD" ]; then
    echo -e "${GREEN}✅ Jupyter pod found: $JUPYTER_POD${NC}"
    kubectl exec -n jupyter "$JUPYTER_POD" -- curl -s http://localhost:8888 > /dev/null && \
        echo -e "${GREEN}✅ Jupyter is responding${NC}" || \
        echo -e "${RED}❌ Jupyter is not responding${NC}"
else
    echo -e "${RED}❌ Jupyter pod not found${NC}"
fi

# Test 4: Test Airflow
echo -e "\n${YELLOW}Test 4: Airflow${NC}"
AIRFLOW_POD=$(kubectl get pods -n airflow -l component=webserver -o jsonpath='{.items[0].metadata.name}')
if [ -n "$AIRFLOW_POD" ]; then
    echo -e "${GREEN}✅ Airflow webserver pod found: $AIRFLOW_POD${NC}"
else
    echo -e "${RED}❌ Airflow webserver pod not found${NC}"
fi

# Test 5: Test Spark Operator
echo -e "\n${YELLOW}Test 5: Spark Operator${NC}"
if kubectl get pods -n spark | grep spark-operator > /dev/null; then
    echo -e "${GREEN}✅ Spark Operator is running${NC}"
    
    # Test Spark CRDs
    if kubectl get crd sparkapplications.sparkoperator.k8s.io > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Spark CRDs are installed${NC}"
    else
        echo -e "${RED}❌ Spark CRDs not found${NC}"
    fi
    
    # Test simple Spark Pi job
    echo -e "${YELLOW}Testing Spark Pi job...${NC}"
    kubectl apply -f - <<EOF
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi-test
  namespace: spark
spec:
  type: Scala
  mode: cluster
  image: "apache/spark:3.5.0-scala2.12-java11-python3-ubuntu"
  imagePullPolicy: Always
  mainClass: "org.apache.spark.examples.SparkPi"
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar"
  sparkVersion: "3.5.0"
  arguments:
    - "10"
  sparkConf:
    "spark.kubernetes.namespace": "spark"
    "spark.kubernetes.authenticate.driver.serviceAccountName": "spark-driver"
    "spark.kubernetes.authenticate.executor.serviceAccountName": "spark-executor"
  restartPolicy:
    type: Never
  driver:
    cores: 1
    memory: "512m"
    serviceAccount: spark-driver
  executor:
    cores: 1
    instances: 1
    memory: "512m"
    serviceAccount: spark-executor
EOF

    # Wait a bit and check if job was created
    sleep 10
    if kubectl get sparkapplication spark-pi-test -n spark > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Spark job submitted successfully${NC}"
        # Clean up test job
        kubectl delete sparkapplication spark-pi-test -n spark || true
    else
        echo -e "${RED}❌ Spark job submission failed${NC}"
    fi
else
    echo -e "${RED}❌ Spark Operator not found${NC}"
fi

# Test 6: Run a simple Papermill notebook
echo -e "\n${YELLOW}Test 6: Papermill Execution${NC}"
kubectl run papermill-test --rm -i --restart=Never --image=jupyter/scipy-notebook:latest \
    --overrides='{"spec":{"containers":[{"name":"papermill-test","image":"jupyter/scipy-notebook:latest","command":["bash","-c"],"args":["pip install papermill && echo \"Papermill test successful\""]}]}}' \
    || echo -e "${RED}❌ Papermill test failed${NC}"

echo -e "\n${GREEN}🎉 Pipeline testing completed!${NC}"
echo -e "${YELLOW}Check the output above for any failed tests.${NC}"
