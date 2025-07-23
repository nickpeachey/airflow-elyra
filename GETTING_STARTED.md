# Getting Started Guide

## Overview

This project provides a complete local Kubernetes data engineering stack that includes:

- **Apache Airflow** for workflow orchestration
- **Jupyter Lab with Elyra** for interactive development
- **Papermill** for parameterized notebook execution
- **Spark Operator** for Kubernetes-native Spark jobs
- **LocalStack** for local AWS services emulation
- **Kind** for local Kubernetes cluster management

## Quick Start (Recommended)

### 1. Install Prerequisites
```bash
./scripts/install-prerequisites.sh
```

This will install:
- Docker Desktop
- kubectl
- Helm
- kind
- yq

### 2. Create Kubernetes Cluster
```bash
./scripts/create-cluster.sh
```

This creates a kind cluster with:
- 1 control plane node
- 2 worker nodes
- Ingress controller
- Required namespaces

### 3. Deploy All Services
```bash
./scripts/deploy-all.sh
```

This deploys:
- RBAC resources for Airflow and Spark
- PostgreSQL (Airflow metadata)
- Redis (Airflow broker)
- Airflow (scheduler, webserver, workers)
- Jupyter Lab with Elyra
- Spark Operator (Kubeflow)
- LocalStack

### 4. Build and Deploy Scala Spark App (Optional)
```bash
./scripts/build-scala-app.sh
```

This will:
- Build the Scala Spark application with SBT
- Upload the JAR to LocalStack S3
- Deploy Spark application manifests

### 5. Verify Installation
```bash
./scripts/status.sh
```

### 6. Test the Pipeline
```bash
./scripts/test-pipeline.sh
```

## Alternative: Development Environment

For simpler local development without Kubernetes:

```bash
./scripts/dev-environment.sh
```

This uses Docker Compose to run a subset of services.

## Access Points

Once deployed, access the services at:

- **Airflow UI**: http://localhost:8080
  - Username: `admin`
  - Password: `admin`
  
- **Jupyter Lab**: http://localhost:8888
  - Token: `datascience123`
  
- **LocalStack**: http://localhost:4566
  - AWS CLI endpoint for S3, SQS, etc.

## Example Workflows

### 1. Running a Papermill Notebook

```bash
# In Jupyter terminal or Airflow task
papermill notebooks/simple_analysis.ipynb \
  notebooks/output/analysis_2024_01_01.ipynb \
  -p execution_date "2024-01-01" \
  -p sample_size 5000
```

### 2. Submitting a Spark Job

```bash
kubectl apply -f spark-apps/data-processing-spark-app.yaml
```

### 3. Creating an Airflow DAG

Place Python files in the `dags/` directory. Example DAGs are provided:
- `data_processing_pipeline.py` - Complete pipeline
- `papermill_example.py` - Simple Papermill example

### 4. Using LocalStack S3

```bash
# Set environment variables
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Use AWS CLI
aws s3 ls --endpoint-url http://localhost:4566
aws s3 mb s3://my-bucket --endpoint-url http://localhost:4566
```

## Project Structure

```
airflow-elyra/
├── README.md                    # Main documentation
├── GETTING_STARTED.md          # This file
├── scripts/                    # Setup and management scripts
│   ├── install-prerequisites.sh
│   ├── create-cluster.sh
│   ├── deploy-all.sh
│   ├── cleanup.sh
│   ├── status.sh
│   ├── dev-environment.sh
│   └── test-pipeline.sh
├── k8s/                        # Kubernetes manifests
│   ├── jupyter/
│   │   └── jupyter-deployment.yaml
│   └── localstack/
│       └── localstack-deployment.yaml
├── helm/                       # Helm values files
│   ├── airflow-values.yaml
│   └── spark-operator-values.yaml
├── dags/                       # Airflow DAGs
│   ├── data_processing_pipeline.py
│   └── papermill_example.py
├── notebooks/                  # Jupyter notebooks
│   ├── data_ingestion.ipynb
│   ├── data_validation.ipynb
│   ├── simple_analysis.ipynb
│   └── output/                 # Generated notebook outputs
├── spark-apps/                 # Spark application definitions
│   ├── data-processing-spark-app.yaml
│   └── data_processing.py
└── config/                     # Configuration files
    ├── .env
    └── docker-compose.dev.yml
```

## Common Tasks

### Viewing Logs
```bash
# Airflow logs
kubectl logs -n airflow deployment/airflow-scheduler -f

# Jupyter logs
kubectl logs -n jupyter deployment/jupyter-lab -f

# LocalStack logs
kubectl logs -n localstack deployment/localstack -f
```

### Port Forwarding (if needed)
```bash
# Airflow UI
kubectl port-forward -n airflow svc/airflow-webserver 8080:8080

# Jupyter Lab
kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888

# LocalStack
kubectl port-forward -n localstack svc/localstack-service 4566:4566
```

### Scaling Services
```bash
# Scale Airflow workers
kubectl scale deployment -n airflow airflow-worker --replicas=3

# Scale Spark Operator
kubectl scale deployment -n spark spark-operator --replicas=2
```

### Updating Configurations
```bash
# Update Airflow configuration
helm upgrade airflow apache-airflow/airflow \
  --namespace airflow \
  --values helm/airflow-values.yaml

# Apply updated Kubernetes manifests
kubectl apply -f k8s/jupyter/
kubectl apply -f k8s/localstack/
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```
   Usually due to resource constraints or PVC issues.

2. **Services not accessible**
   ```bash
   kubectl get svc --all-namespaces
   kubectl describe svc <service-name> -n <namespace>
   ```
   Check service endpoints and port configurations.

3. **Persistent Volume issues**
   ```bash
   kubectl get pv,pvc --all-namespaces
   ```
   Ensure storage class exists and volumes are bound.

4. **Airflow tasks failing**
   - Check Airflow logs in the UI
   - Verify Kubernetes permissions
   - Ensure Docker images are accessible

### Getting Help

1. Check service status: `./scripts/status.sh`
2. View pod logs: `kubectl logs <pod-name> -n <namespace>`
3. Test connectivity: `./scripts/test-pipeline.sh`
4. Clean and restart: `./scripts/cleanup.sh && ./scripts/create-cluster.sh && ./scripts/deploy-all.sh`

## Next Steps

1. **Customize the stack** by modifying Helm values and Kubernetes manifests
2. **Add your own DAGs** to the `dags/` directory
3. **Create custom notebooks** in the `notebooks/` directory
4. **Build custom Spark applications** in the `spark-apps/` directory
5. **Set up monitoring** with Prometheus and Grafana
6. **Add CI/CD** integration for automated deployments

## Security Considerations

This setup is designed for local development and testing. For production use:

1. Change default passwords and tokens
2. Enable authentication and authorization
3. Use proper TLS certificates
4. Implement network policies
5. Use secrets management
6. Enable audit logging
7. Regular security updates

## Performance Tuning

For better performance:

1. Adjust resource limits in Kubernetes manifests
2. Configure Spark executor and driver resources
3. Tune Airflow worker concurrency
4. Optimize database connections
5. Use appropriate storage classes
6. Monitor resource usage

Happy data engineering! 🚀
