#!/bin/bash
set -e

echo "🏗️ Creating local Kubernetes cluster with kind..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CLUSTER_NAME="data-engineering-stack"

# Check if cluster already exists
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo -e "${YELLOW}Cluster '$CLUSTER_NAME' already exists. Deleting it...${NC}"
    kind delete cluster --name "$CLUSTER_NAME"
fi

echo -e "${YELLOW}Creating new cluster '$CLUSTER_NAME'...${NC}"

# Create cluster with kind config
cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 8080
    hostPort: 8080
    protocol: TCP
  - containerPort: 8888
    hostPort: 8888
    protocol: TCP
  - containerPort: 4566
    hostPort: 4566
    protocol: TCP
- role: worker
- role: worker
EOF

# Wait for cluster to be ready
echo -e "${YELLOW}Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install NGINX Ingress Controller
echo -e "${YELLOW}Installing NGINX Ingress Controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Add Helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add apache-airflow https://airflow.apache.org
helm repo add kubeflow https://kubeflow.github.io/spark-operator
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create namespaces
echo -e "${YELLOW}Creating namespaces...${NC}"
kubectl create namespace airflow --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace jupyter --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace spark --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace localstack --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Cluster '$CLUSTER_NAME' created successfully!${NC}"
echo -e "${YELLOW}Cluster info:${NC}"
kubectl cluster-info --context kind-$CLUSTER_NAME
