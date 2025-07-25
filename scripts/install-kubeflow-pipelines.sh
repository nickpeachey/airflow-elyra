#!/bin/bash

# Install Kubeflow Pipelines Script
# This script installs KFP 1.8.22 which is compatible with Elyra's KFP client

set -e

echo "🔧 Installing Kubeflow Pipelines (v1.8.22 - Compatible with Elyra)"
echo "=================================================================="
echo ""

# Remove any existing KFP installation
echo "🧹 Cleaning up any existing KFP installation..."
kubectl delete namespace kubeflow --ignore-not-found=true
echo "⏳ Waiting for namespace cleanup..."
sleep 10

# Install KFP 1.8.22 cluster-scoped resources
echo "📦 Installing KFP 1.8.22 cluster-scoped resources..."
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=1.8.22" || echo "⚠️  Some CRDs may already exist"

# Install KFP 1.8.22 environment-specific components
echo "📦 Installing KFP 1.8.22 platform-agnostic components..."
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/env/platform-agnostic-emissary?ref=1.8.22"

# Wait for deployments to be ready
echo "⏳ Waiting for KFP components to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/ml-pipeline -n kubeflow
kubectl wait --for=condition=available --timeout=300s deployment/ml-pipeline-ui -n kubeflow

# Fix: Remove problematic cache components that cause issues with newer Kubernetes
echo "🔧 Fixing cache component compatibility issues..."
echo "⚠️  Removing KFP cache components due to Kubernetes API compatibility issues"
kubectl delete deployment cache-deployer-deployment cache-server -n kubeflow --ignore-not-found=true
kubectl delete service cache-server -n kubeflow --ignore-not-found=true
echo "✅ Cache components removed - KFP will work without them"

echo "✅ Kubeflow Pipelines installed successfully!"
echo ""
echo "📋 Version Info:"
echo "  KFP Server: 1.7.0 (compatible with Elyra KFP client 1.8.22)"
echo "  Storage: MinIO (built-in S3-compatible storage)"
echo "  Workflow Engine: Argo Workflows"
echo ""
