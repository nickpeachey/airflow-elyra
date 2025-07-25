#!/bin/bash

set -e

echo "🏗️  Building custom Jupyter image with Elyra..."

# Build the Docker image
docker build -t jupyter-elyra:latest ./docker/jupyter-elyra/

# Tag for local registry (if using kind)
docker tag jupyter-elyra:latest localhost:5001/jupyter-elyra:latest

echo "✅ Image built successfully!"
echo ""
echo "🔄 Loading image into kind cluster..."

# Load image into kind cluster
kind load docker-image jupyter-elyra:latest --name data-engineering-stack

echo "✅ Image loaded into kind cluster!"
echo ""
echo "📝 Next steps:"
echo "   1. Update jupyter-deployment.yaml to use 'jupyter-elyra:latest'"
echo "   2. Remove the postStart lifecycle hook"
echo "   3. Apply the updated deployment"
echo ""
echo "🚀 Ready to deploy!"
