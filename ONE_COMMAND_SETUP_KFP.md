# One Command Setup for Elyra + Kubeflow Pipelines

This guide provides a single command to set up the complete Elyra + Kubeflow Pipelines environment.

## Prerequisites

1. **Docker** running
2. **kubectl** installed  
3. **kind** installed
4. **AWS CLI** installed (for LocalStack S3 operations)

## Quick Start

Run the complete setup with one command:

```bash
./scripts/setup-complete.sh
```

This script will automatically:

✅ **Create Kind cluster** with 3 nodes (create-cluster.sh)  
✅ **Build custom Jupyter image** with Elyra 3.15.0 (build-jupyter-image.sh)  
✅ **Install Kubeflow Pipelines v1.8.22** (compatible with Elyra)  
✅ **Deploy LocalStack S3** to the cluster  
✅ **Set up S3 buckets** with all required buckets  
✅ **Deploy Jupyter Lab** with Elyra to the cluster  
✅ **Configure Elyra runtime** for KFP with correct credentials  
✅ **Deploy sample notebooks** with cluster-internal endpoints  
✅ **Set up port forwarding** for all services  
✅ **Verify connectivity** and report status  

## What Gets Installed

### Core Components
- **Kubeflow Pipelines 1.8.22**: Compatible with Elyra's KFP client
- **MinIO Storage**: S3-compatible storage for pipeline artifacts
- **LocalStack**: S3-compatible storage for notebook data
- **Argo Workflows**: Workflow execution engine

### Configuration
- **KFP Runtime**: Pre-configured for Elyra with correct endpoints
- **S3 Buckets**: All required buckets created automatically
- **Notebooks**: Sample notebooks with cluster-internal endpoints
- **Port Forwarding**: All services accessible via localhost

## Access URLs

After setup completes, access these URLs:

- **Jupyter Lab**: http://localhost:8888
- **KFP UI**: http://localhost:8882  
- **KFP API**: http://localhost:8881
- **LocalStack**: http://localhost:4566
- **Airflow UI**: http://localhost:8080 (admin/admin)

## Testing the Setup

1. Open Jupyter Lab at http://localhost:8888
2. Create a new Pipeline using the Pipeline Editor
3. Drag notebooks into your pipeline
4. Select "Kubeflow Pipelines" as runtime
5. Submit your pipeline!

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Jupyter Lab   │    │ Kubeflow         │    │   LocalStack    │
│   + Elyra       │───▶│ Pipelines        │    │   (S3 Storage)  │
│                 │    │ v1.8.22          │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌──────────────────┐            │
         │              │     MinIO        │            │
         │              │  (Pipeline       │            │
         └──────────────│   Artifacts)     │◀───────────┘
                        └──────────────────┘
```

## Manual Steps (if needed)

If the automatic setup fails, you can run individual components:

```bash
# Install KFP only
./scripts/install-kubeflow-pipelines.sh

# Setup LocalStack buckets only  
./scripts/setup-localstack-buckets.sh

# Configure Elyra runtime only
./scripts/configure-elyra-kfp.sh

# Deploy notebooks only
./scripts/deploy-content.sh
```

## Troubleshooting

### Port Conflicts
If ports are already in use:
```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Restart setup
./scripts/setup-complete.sh
```

### Pod Issues
Check pod status:
```bash
kubectl get pods --all-namespaces
```

### Connection Issues
Test service connectivity:
```bash
# Test KFP API
curl http://localhost:8881/apis/v1beta1/healthz

# Test LocalStack
curl http://localhost:4566/health
```

## Version Compatibility

This setup uses specifically compatible versions:

- **KFP Server**: 1.7.0 (part of v1.8.22 release)
- **KFP Client** (in Elyra): 1.8.22
- **Elyra**: 3.15.0+
- **Python**: 3.9+

## What's Different from Standard KFP

1. **Version Selection**: Uses KFP 1.8.22 instead of latest 2.x
2. **Dual Storage**: MinIO for pipelines + LocalStack for notebook data
3. **Pre-configured Runtime**: Elyra runtime automatically configured
4. **Cluster Endpoints**: Notebooks use internal cluster endpoints
5. **Complete Automation**: Everything configured in one command

This ensures Elyra works perfectly with KFP without version compatibility issues!
