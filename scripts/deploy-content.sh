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
for notebook_file in notebooks/*_fixed.ipynb notebooks/elyra_test_pipeline.ipynb; do
    if [ -f "$notebook_file" ]; then
        echo "  Copying $(basename $notebook_file)..."
        kubectl cp "$notebook_file" jupyter/"$JUPYTER_POD":/home/jovyan/work/$(basename $notebook_file)
    fi
done

# Fix LocalStack endpoints in notebooks for cluster-internal access
echo "🔧 Updating LocalStack endpoints for cluster-internal access..."
kubectl exec -n jupyter "$JUPYTER_POD" -- bash -c 'find /home/jovyan/work -name "*_fixed.ipynb" -exec sed -i "s|http://localhost:4566|http://localstack-service.localstack:4566|g" {} \;'

# Add proper kernelspec metadata to all notebooks for Elyra compatibility
echo "🔧 Adding kernelspec metadata to notebooks for Elyra pipeline compatibility..."
kubectl exec -n jupyter "$JUPYTER_POD" -- python3 -c "
import json
import os
import glob

# Define proper metadata
kernelspec = {
    'display_name': 'Python 3 (ipykernel)',
    'language': 'python',
    'name': 'python3'
}

language_info = {
    'codemirror_mode': {
        'name': 'ipython',
        'version': 3
    },
    'file_extension': '.py',
    'mimetype': 'text/x-python',
    'name': 'python',
    'nbconvert_exporter': 'python',
    'pygments_lexer': 'ipython3',
    'version': '3.9.7'
}

# Find all notebooks
notebooks = glob.glob('/home/jovyan/work/**/*.ipynb', recursive=True)
print(f'📋 Found {len(notebooks)} notebooks to update')

for nb_path in notebooks:
    try:
        # Skip checkpoint files
        if 'checkpoint' in nb_path:
            continue
            
        print(f'   Updating: {os.path.basename(nb_path)}')
        
        # Read notebook
        with open(nb_path, 'r') as f:
            nb = json.load(f)
        
        # Update metadata
        if 'metadata' not in nb:
            nb['metadata'] = {}
            
        nb['metadata']['kernelspec'] = kernelspec
        nb['metadata']['language_info'] = language_info
        
        # Save updated notebook
        with open(nb_path, 'w') as f:
            json.dump(nb, f, indent=1)
            
    except Exception as e:
        print(f'   ❌ Error processing {nb_path}: {e}')

print('✅ All notebooks updated with proper kernelspec metadata!')
"

echo "✅ Notebooks deployed successfully!"
echo ""
echo "🌐 Access URLs:"
echo "  • Airflow UI: http://localhost:8080 (admin/admin)"
echo "  • Jupyter Lab: http://localhost:8888"
echo "  • KFP UI: http://localhost:8882"
echo "  • KFP API: http://localhost:8881"
echo ""
echo "📋 DAGs are automatically synced from GitHub repository:"
echo "  Repository: https://github.com/nickpeachey/airflow-elyra"
echo "  Sync interval: 60 seconds"
echo "  Check the Airflow UI for available DAGs after sync completes."
