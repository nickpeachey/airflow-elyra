#!/bin/bash

# Notebook JSON Validation Script
# This script validates all Jupyter notebooks in the notebooks/ directory

set -e

echo "🔍 Validating Notebook JSON Structure..."
echo "========================================"

# Python validation script
python3 << 'EOF'
import json
import os
import glob
import sys

def validate_notebook(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            notebook_data = json.loads(content)
            
        # Validate required notebook structure
        required_keys = ['cells', 'metadata', 'nbformat', 'nbformat_minor']
        missing_keys = [key for key in required_keys if key not in notebook_data]
        
        if missing_keys:
            return False, f'Missing required keys: {missing_keys}'
            
        if not isinstance(notebook_data['cells'], list):
            return False, 'cells must be a list'
        
        # Check for proper cell structure
        for i, cell in enumerate(notebook_data['cells']):
            if 'cell_type' not in cell:
                return False, f'Cell {i} missing cell_type'
            if 'source' not in cell:
                return False, f'Cell {i} missing source'
                
        # Count cell types
        cell_count = len(notebook_data['cells'])
        code_cells = sum(1 for cell in notebook_data['cells'] if cell.get('cell_type') == 'code')
        markdown_cells = sum(1 for cell in notebook_data['cells'] if cell.get('cell_type') == 'markdown')
        
        # Check endpoints
        content_str = str(notebook_data)
        endpoint_status = ""
        if 'localstack-service.localstack:4566' in content_str:
            endpoint_status = " [cluster endpoints ✅]"
        elif 'localhost:4566' in content_str:
            endpoint_status = " [localhost endpoints ⚠️]"
            
        return True, f'Valid (nbformat {notebook_data.get("nbformat", "?")}.{notebook_data.get("nbformat_minor", "?")}) - {cell_count} cells ({code_cells} code, {markdown_cells} markdown){endpoint_status}'
        
    except json.JSONDecodeError as e:
        return False, f'JSON Error: {str(e)}'
    except Exception as e:
        return False, f'Error: {str(e)}'

def main():
    # Get all notebook files
    notebook_files = glob.glob('notebooks/*.ipynb')
    notebook_files = list(set(notebook_files))  # Remove duplicates
    notebook_files.sort()
    
    if not notebook_files:
        print("No notebook files found in notebooks/ directory")
        return 0
    
    print(f"Found {len(notebook_files)} notebook files:")
    print()
    
    valid_count = 0
    invalid_count = 0
    endpoint_warnings = 0
    
    for notebook in notebook_files:
        is_valid, message = validate_notebook(notebook)
        status = '✅' if is_valid else '❌'
        filename = os.path.basename(notebook)
        
        print(f'{status} {filename:<35} {message}')
        
        if is_valid:
            valid_count += 1
            if 'localhost endpoints ⚠️' in message:
                endpoint_warnings += 1
        else:
            invalid_count += 1
    
    print()
    print("=" * 80)
    print(f"Summary: {valid_count} valid, {invalid_count} invalid notebook(s)")
    
    if endpoint_warnings > 0:
        print(f"⚠️  {endpoint_warnings} notebook(s) use localhost endpoints instead of cluster-internal")
        print("   Run: sed -i 's/localhost:4566/localstack-service.localstack:4566/g' notebooks/*.ipynb")
    
    if invalid_count == 0:
        print("🎉 All notebooks have valid JSON structure!")
        return 0
    else:
        print("❌ Some notebooks have invalid JSON structure!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOF

validation_result=$?

if [ $validation_result -eq 0 ]; then
    echo
    echo "✅ All notebooks passed validation!"
else
    echo
    echo "❌ Notebook validation failed!"
    exit 1
fi
