#!/bin/bash
set -e

echo "🚀 Installing prerequisites for the data engineering stack..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}This script is designed for macOS. Please install prerequisites manually on other systems.${NC}"
    exit 1
fi

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Docker Desktop
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Desktop...${NC}"
    brew install --cask docker
    echo -e "${YELLOW}Please start Docker Desktop manually and ensure it's running.${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Installing kubectl...${NC}"
    brew install kubectl
else
    echo -e "${GREEN}✓ kubectl already installed${NC}"
fi

# Install Helm
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Installing Helm...${NC}"
    brew install helm
else
    echo -e "${GREEN}✓ Helm already installed${NC}"
fi

# Install kind
if ! command -v kind &> /dev/null; then
    echo -e "${YELLOW}Installing kind...${NC}"
    brew install kind
else
    echo -e "${GREEN}✓ kind already installed${NC}"
fi

# Install yq for YAML processing
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}Installing yq...${NC}"
    brew install yq
else
    echo -e "${GREEN}✓ yq already installed${NC}"
fi

# Verify Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Docker is running${NC}"
fi

echo -e "${GREEN}🎉 All prerequisites installed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run: ./scripts/create-cluster.sh"
echo "2. Run: ./scripts/deploy-all.sh"
