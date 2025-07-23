#!/bin/bash
set -e

echo "🔧 Running development environment with Docker Compose..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting development environment...${NC}"
cd "$PROJECT_ROOT"

# Create output directory for notebooks
mkdir -p notebooks/output

# Start services
docker-compose -f config/docker-compose.dev.yml up -d

echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Initialize LocalStack
echo -e "${YELLOW}Initializing LocalStack...${NC}"
sleep 5

# Create S3 buckets
docker-compose -f config/docker-compose.dev.yml exec -T localstack aws --endpoint-url=http://localhost:4566 s3 mb s3://data-lake || true
docker-compose -f config/docker-compose.dev.yml exec -T localstack aws --endpoint-url=http://localhost:4566 s3 mb s3://processed-data || true
docker-compose -f config/docker-compose.dev.yml exec -T localstack aws --endpoint-url=http://localhost:4566 s3 mb s3://notebooks || true

echo -e "${GREEN}🎉 Development environment is ready!${NC}"
echo -e "${YELLOW}Access URLs:${NC}"
echo "• Jupyter Lab: http://localhost:8888 (token: datascience123)"
echo "• LocalStack: http://localhost:4566"
echo "• PostgreSQL: localhost:5432 (airflow/airflow)"
echo "• Redis: localhost:6379"
echo ""
echo -e "${YELLOW}To stop the environment:${NC}"
echo "docker-compose -f config/docker-compose.dev.yml down"
