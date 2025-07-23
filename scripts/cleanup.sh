#!/bin/bash
set -e

echo "🧹 Cleaning up the data engineering stack..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CLUSTER_NAME="data-engineering-stack"

# Check if cluster exists
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo -e "${YELLOW}Deleting kind cluster '$CLUSTER_NAME'...${NC}"
    kind delete cluster --name "$CLUSTER_NAME"
    echo -e "${GREEN}✅ Cluster deleted successfully!${NC}"
else
    echo -e "${YELLOW}Cluster '$CLUSTER_NAME' not found.${NC}"
fi

# Clean up any leftover Docker containers
echo -e "${YELLOW}Cleaning up Docker containers...${NC}"
docker container prune -f

echo -e "${GREEN}🎉 Cleanup completed!${NC}"
