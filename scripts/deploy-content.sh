#!/bin/bash

# Deploy Non-DAG Content Script
# This script only copies notebooks to Jupyter pods
# DAGs are now automatically synced from GitHub repository

set -e

echo "📋 Deploying Non-DAG Content (Notebooks only - DAGs come from Git)"
echo "================================================================"
echo ""
echo "ℹ️  Note: DAGs are now automatically synced from GitHub repository"
echo "   Repository: https://github.com/nickpeachey/airflow-elyra"
echo "   DAGs will be pulled automatically every 60 seconds"
echo ""

# Wait for Jupyter pod to be ready
echo "⏳ Waiting for Jupyter pod to be ready..."
kubectl wait --for=condition=ready pod -l app=jupyter-lab -n jupyter --timeout=300s

# Get pod names
JUPYTER_POD=$(kubectl get pods -n jupyter -l app=jupyter-lab -o jsonpath='{.items[0].metadata.name}')

echo "📋 Found pods:"
echo "  Jupyter: $JUPYTER_POD"

# Copy notebooks to Jupyter
echo "📓 Copying notebooks to Jupyter..."
for notebook_file in notebooks/*_fixed.ipynb; do
    if [ -f "$notebook_file" ]; then
        echo "  Copying $(basename $notebook_file)..."
        kubectl cp "$notebook_file" jupyter/"$JUPYTER_POD":/home/jovyan/work/$(basename $notebook_file)
    fi
done

echo "✅ Notebooks deployed successfully!"
echo ""
echo "🌐 Access URLs:"
echo "  • Airflow UI: http://localhost:8080 (admin/admin)"
echo "  • Jupyter Lab: http://localhost:8888"
echo ""
echo "📋 DAGs are automatically synced from GitHub repository:"
echo "  Repository: https://github.com/nickpeachey/airflow-elyra"
echo "  Sync interval: 60 seconds"
echo "  Check the Airflow UI for available DAGs after sync completes."
