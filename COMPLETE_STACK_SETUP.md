# Complete Data Engineering Stack - One Command Setup

This guide provides a single command to set up the **complete** data engineering stack that includes both traditional Airflow DAGs and visual pipeline development.

## What Gets Deployed

This script deploys **EVERYTHING** in the correct order:

### Phase 1: Traditional Stack
- ✅ **Kind Kubernetes cluster** (3 nodes)
- ✅ **Apache Airflow 2.10.5** with PostgreSQL & Redis
- ✅ **SparkOperator** with authentic SparkKubernetesOperator
- ✅ **Apache Spark 3.5.5** with complete S3 integration
- ✅ **LocalStack S3** with buckets and sample data
- ✅ **Jupyter Lab** for interactive development
- ✅ **GitHub DAG synchronization**

### Phase 2: Visual Pipeline Stack
- ✅ **Custom Jupyter image** with Elyra 3.15.0
- ✅ **Kubeflow Pipelines v1.8.22** (compatible with Elyra)
- ✅ **Elyra runtime configuration** for KFP
- ✅ **Visual pipeline development** environment

## Prerequisites

1. **Docker** running
2. **kubectl** installed  
3. **kind** installed
4. **helm** installed
5. **AWS CLI** installed (for LocalStack S3 operations)

## Quick Start

Run the complete setup with one command:

```bash
./scripts/deploy-complete-stack.sh
```

This script will automatically deploy both stacks in the correct order and provide you with a complete working environment.

## What You Get

### Traditional Workflow (Airflow DAGs)
- **Web UI**: http://localhost:8080 (admin/admin)
- **SparkOperator**: Authentic Spark job execution
- **GitHub Sync**: DAGs automatically sync from repository
- **S3 Integration**: Complete data processing pipeline

### Visual Workflow (Elyra + KFP)
- **Jupyter Lab**: http://localhost:8888 (with visual pipeline editor)
- **KFP UI**: http://localhost:8882 (pipeline monitoring)
- **Drag & Drop**: Create pipelines visually
- **Kubernetes Execution**: Real pipeline execution on K8s

## Port Forwarding

After deployment, run these commands in separate terminals:

```bash
# Traditional stack
kubectl port-forward -n airflow svc/airflow-webserver 8080:8080
kubectl port-forward -n localstack svc/localstack-service 4566:4566

# Visual pipeline stack  
kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888
kubectl port-forward -n kubeflow svc/ml-pipeline-ui 8882:80
kubectl port-forward -n kubeflow svc/ml-pipeline 8881:8888
```

## Development Approaches

### 1. Traditional Airflow Development
- Write Python DAGs using PythonOperator for data processing
- Commit to GitHub - DAGs sync automatically
- Monitor in Airflow UI
- Perfect for production workflows
- Note: SparkKubernetesOperator requires proper RBAC and kubectl access

### 2. Visual Pipeline Development  
- Use Elyra's drag-and-drop pipeline editor
- Connect notebooks visually
- Execute on Kubeflow Pipelines
- Perfect for experimentation and prototyping

## Both Approaches Share
- **Same S3 Storage**: LocalStack buckets accessible to both
- **Same Cluster**: All running on the same Kubernetes cluster
- **Same Data**: Process the same datasets with different tools

## Monitoring & Management

```bash
# View all components
kubectl get pods --all-namespaces

# Monitor traditional Spark jobs
kubectl get sparkapplications -w

# Monitor visual pipelines
kubectl get workflows -n kubeflow

# Check S3 data
kubectl exec -n localstack deployment/localstack -- awslocal s3 ls s3://data-engineering-bucket/ --recursive

# Get Jupyter token
kubectl logs -n jupyter deployment/jupyter-lab | grep -E 'token=|/?token='
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kind Kubernetes Cluster                  │
├─────────────────────────────────────────────────────────────┤
│  Traditional Stack              │  Visual Pipeline Stack    │
│  ├─ Airflow 2.10.5             │  ├─ Jupyter + Elyra      │
│  ├─ SparkOperator              │  ├─ Kubeflow Pipelines   │
│  ├─ PostgreSQL/Redis           │  ├─ MinIO (KFP storage)  │
│  └─ GitHub DAG Sync            │  └─ Argo Workflows       │
├─────────────────────────────────────────────────────────────┤
│              Shared Components                              │
│  ├─ LocalStack S3 (shared storage)                        │
│  ├─ Apache Spark 3.5.5                                    │
│  └─ Sample datasets                                        │
└─────────────────────────────────────────────────────────────┘
```

## Use Cases

### Traditional Airflow DAGs
- **Production workflows** with complex dependencies
- **Scheduled data processing** with SparkOperator
- **Enterprise-grade** pipeline orchestration
- **Code-based** pipeline definition

### Visual Elyra Pipelines
- **Rapid prototyping** of data workflows
- **Notebook-based** data science workflows
- **Visual pipeline** creation and editing
- **Interactive development** and testing

## Cleanup

To remove everything:

```bash
./scripts/cleanup.sh
```

## Support

- **Traditional stack**: See `SPARKOPERATOR_SETUP.md`
- **Visual pipelines**: See `ONE_COMMAND_SETUP_KFP.md`
- **Issues**: Check individual component logs with kubectl

## Summary

This setup gives you the **best of both worlds**:
- Traditional Airflow for production-grade DAG orchestration
- Visual Elyra for interactive pipeline development
- Both sharing the same underlying infrastructure and data storage

Choose the approach that fits your workflow, or use both! 🚀
