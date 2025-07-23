#!/bin/bash

# Quick validation of the master deployment script
# This tests the script without actually deploying anything

echo "🧪 Testing deploy-everything.sh script validation..."

# Test 1: Check if script exists and is executable
if [[ ! -x "scripts/deploy-everything.sh" ]]; then
    echo "❌ deploy-everything.sh is not executable"
    exit 1
fi

echo "✅ Script is executable"

# Test 2: Check if all referenced scripts exist
REQUIRED_SCRIPTS=(
    "scripts/cleanup.sh"
    "scripts/create-cluster.sh" 
    "scripts/deploy-all.sh"
    "scripts/test-sparkoperator.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
        echo "❌ Missing required script: $script"
        exit 1
    fi
done

echo "✅ All required scripts exist"

# Test 3: Check if all referenced files exist
REQUIRED_FILES=(
    "dags/spark_operator_s3.py"
    "dags/spark_application.yaml"
    "spark-apps/spark_s3_job.py"
    "data/sales_data.csv"
    "ONE_COMMAND_SETUP.md"
    "SPARKOPERATOR_SETUP.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Missing required file: $file"
        exit 1
    fi
done

echo "✅ All required files exist"

# Test 4: Check if prerequisites are mentioned correctly
if ! grep -q "kind\|kubectl\|helm\|docker" scripts/deploy-everything.sh; then
    echo "❌ Prerequisites not properly checked in script"
    exit 1
fi

echo "✅ Prerequisites are checked"

# Test 5: Validate the script structure
if ! grep -q "print_step" scripts/deploy-everything.sh; then
    echo "❌ Step structure not found in script"
    exit 1
fi

echo "✅ Script structure is valid"

echo ""
echo "🎉 All validations passed! The master script is ready to use."
echo ""
echo "To deploy everything, run:"
echo "  ./scripts/deploy-everything.sh"
echo ""
echo "For unattended deployment:"
echo "  AUTO_YES=true ./scripts/deploy-everything.sh"
