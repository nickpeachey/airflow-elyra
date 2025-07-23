#!/bin/bash

# Summary of available scripts and what they do

echo "🗂️  COMPLETE SCRIPT OVERVIEW"
echo "=============================="
echo ""

echo "🎯 MAIN SCRIPT (THE ONLY ONE YOU NEED):"
echo "  ./scripts/deploy-everything.sh"
echo "    ↳ Master script that orchestrates everything"
echo "    ↳ Calls all other scripts in the correct order"
echo "    ↳ One command deploys the entire stack"
echo ""

echo "🧪 VALIDATION & TESTING:"
echo "  ./scripts/validate-setup.sh"
echo "    ↳ Validates that all files and scripts are ready"
echo "  ./scripts/test-sparkoperator.sh"
echo "    ↳ Tests the SparkOperator pipeline end-to-end"
echo ""

echo "🔧 INDIVIDUAL SCRIPTS (called automatically by deploy-everything.sh):"
echo "  ./scripts/cleanup.sh"
echo "    ↳ Removes all infrastructure (kind cluster, containers)"
echo "  ./scripts/create-cluster.sh"
echo "    ↳ Creates a 3-node kind Kubernetes cluster"
echo "  ./scripts/deploy-all.sh"
echo "    ↳ Deploys all services and sets up SparkOperator"
echo "  ./scripts/deploy-content.sh"
echo "    ↳ Deploys DAGs and notebooks to running services"
echo ""

echo "📚 DOCUMENTATION:"
echo "  ONE_COMMAND_SETUP.md"
echo "    ↳ Quick start guide for the master script"
echo "  SPARKOPERATOR_SETUP.md"
echo "    ↳ Detailed technical documentation"
echo "  README.md"
echo "    ↳ Main project documentation"
echo ""

echo "🚀 QUICK START:"
echo "  1. ./scripts/deploy-everything.sh     # Deploy everything"
echo "  2. kubectl port-forward -n airflow svc/airflow-webserver 8080:8080"
echo "  3. Open http://localhost:8080 (admin/admin)"
echo "  4. Run the spark_operator_s3_pipeline DAG"
echo ""

echo "💡 FOR AUTOMATION:"
echo "  AUTO_YES=true ./scripts/deploy-everything.sh"
echo "    ↳ Runs without interactive prompts"
echo ""

echo "🎯 WHAT YOU GET:"
echo "  ✅ Complete Kubernetes data engineering stack"
echo "  ✅ Authentic SparkOperator with S3 integration"
echo "  ✅ Working analytics pipeline with real data"
echo "  ✅ Airflow, Jupyter, LocalStack all configured"
echo "  ✅ Production-ready configuration with RBAC"
echo ""

echo "Ready to deploy? Run: ./scripts/deploy-everything.sh 🚀"
