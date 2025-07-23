# Local Kubernetes Data Engineering Stack

This project provides a complete local Kubernetes setup for data engineering workflows, including:

- **Apache Airflow 2.10.5** - Workflow orchestration with web UI
- **Jupyter Lab with Elyra** - Interactive development and pipeline editor
- **Papermill** - Parameterized notebook execution  
- **Spark Operator (Kubeflow)** - Kubernetes-native Spark jobs with authentic SparkKubernetesOperator
- **LocalStack** - Local AWS services emulation with S3 integration
- **Kind** - Local Kubernetes cluster

## 🚀 ONE-COMMAND DEPLOYMENT

**NEW**: Deploy everything with a single command!

```bash
./scripts/deploy-everything.sh
```

This master script will:
- Clean up any existing setup
- Create a 3-node Kind cluster
- Deploy all services (Airflow, SparkOperator, Jupyter, LocalStack)
- Set up S3 buckets with sample data
- Configure authentic SparkOperator with S3 integration
- Test the complete pipeline

**Result**: Complete working data engineering stack in ~5 minutes! ⚡

For detailed instructions, see: [ONE_COMMAND_SETUP.md](ONE_COMMAND_SETUP.md)

## 🎯 What You Get

- ✅ **Authentic SparkOperator** using SparkKubernetesOperator (not simple k8s jobs)
- ✅ **Apache Spark 3.5.5** with proven S3 integration
- ✅ **Real data processing** pipeline with comprehensive analytics
- ✅ **Production-ready configuration** with proper RBAC and security
- ✅ **Sample sales data** (100 transactions) for immediate testing
- ✅ **Complete S3 workflow** (read from S3, process, write back to S3)

## 📊 Ready-to-Use Pipeline

The deployment includes a working `spark_operator_s3_pipeline` DAG that:
- Reads sales data from S3
- Performs regional, category, and customer analysis
- Calculates daily metrics
- Saves all results back to S3 buckets

## 🔧 Alternative Setup (Manual)
1. Install all prerequisites
2. Create the Kubernetes cluster
3. Deploy all services
4. Deploy DAGs and notebooks
5. Start port forwarding

## ✅ What's Included

After setup, you'll have:

- ✅ **4 Working DAGs** automatically deployed
- ✅ **Interactive Jupyter Lab** with notebooks
- ✅ **Spark job execution** capabilities
- ✅ **LocalStack S3** for data storage
- ✅ **Web UIs** accessible on localhost

## 🌐 Access Points

- **Airflow UI**: http://localhost:8080 (admin/admin)
- **Jupyter Lab**: http://localhost:8888 (check logs for token)
- **LocalStack**: http://localhost:4566

## 🪣 Viewing S3 Buckets

LocalStack provides S3-compatible storage. You can view and interact with buckets in several ways:

### Quick View
```bash
# List all buckets
aws --endpoint-url=http://localhost:4566 s3 ls

# Create a bucket
aws --endpoint-url=http://localhost:4566 s3 mb s3://my-data-bucket

# Upload a file
aws --endpoint-url=http://localhost:4566 s3 cp myfile.txt s3://my-data-bucket/
```

### Comprehensive View
```bash
# Run the bucket viewer script
./scripts/view-s3-buckets.sh
```

### From Python/Jupyter
```python
import boto3

s3_client = boto3.client(
    's3',
    endpoint_url='http://localhost:4566',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

# List buckets
buckets = s3_client.list_buckets()
for bucket in buckets['Buckets']:
    print(f"📦 {bucket['Name']}")
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Local Kubernetes Cluster (kind)          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Airflow   │  │ Jupyter Lab │  │ LocalStack  │          │
│  │  Scheduler  │  │   + Elyra   │  │  (AWS Mock) │          │
│  │  Webserver  │  │ + Papermill │  │             │          │
│  │             │  │             │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │    Spark    │  │ PostgreSQL  │  │   Redis     │          │
│  │  Operator   │  │ (Metadata)  │  │  (Broker)   │          │
│  │             │  │             │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Docker Desktop
- kubectl
- Helm
- kind

## Quick Start

1. **Install Prerequisites**
   ```bash
   ./scripts/install-prerequisites.sh
   ```

2. **Create Kubernetes Cluster**
   ```bash
   ./scripts/create-cluster.sh
   ```

3. **Deploy All Services**
   ```bash
   ./scripts/deploy-all.sh
   ```

4. **Access Services**
   - Airflow UI: http://localhost:8080 (admin/admin)
   - Jupyter Lab: http://localhost:8888 (token in logs)
   - LocalStack: http://localhost:4566

## Components

### Airflow
- Web UI for workflow management
- Scheduler for task execution
- Worker for task processing
- PostgreSQL backend
- Redis for message brokering

### Jupyter Lab + Elyra
- Interactive notebook environment
- Elyra extension for visual pipeline creation
- Papermill integration for parameterized execution
- Spark integration

### Spark Operator
- Kubernetes-native Spark job execution
- SparkApplication CRDs
- Automatic resource management

### LocalStack
- S3-compatible storage
- SQS, SNS, Lambda emulation
- Perfect for testing AWS integrations

## Usage Examples

### Running a Spark Job
```python
# In Jupyter notebook
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("DataProcessing") \
    .getOrCreate()

# Your Spark code here
```

### Creating an Airflow DAG
```python
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator

dag = DAG('spark_example', ...)

spark_task = SparkKubernetesOperator(
    task_id='spark_job',
    application_file='spark-app.yaml',
    dag=dag
)
```

### Using Papermill
```bash
papermill input.ipynb output.ipynb -p param1 value1
```

## Directory Structure

```
airflow-elyra/
├── README.md
├── scripts/                 # Setup and management scripts
├── k8s/                     # Kubernetes manifests
│   ├── airflow/            # Airflow deployment
│   ├── jupyter/            # Jupyter Lab deployment
│   ├── spark/              # Spark Operator
│   └── localstack/         # LocalStack deployment
├── helm/                   # Helm charts
├── dags/                   # Airflow DAGs
├── notebooks/              # Jupyter notebooks
├── spark-apps/             # Spark application definitions
└── config/                 # Configuration files
```

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   ./scripts/cleanup.sh
   ```

2. **Pods Not Starting**
   ```bash
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   ```

3. **Cannot Access LocalStack S3**
   ```bash
   # Check if LocalStack is running
   kubectl get pods -n localstack
   
   # Start port forwarding if needed
   kubectl port-forward -n localstack svc/localstack-service 4566:4566 &
   
   # View buckets
   ./scripts/view-s3-buckets.sh
   ```

4. **DAGs Not Visible in Airflow**
   ```bash
   # Redeploy DAGs and notebooks
   ./scripts/deploy-content.sh
   ```

5. **Storage Issues**
   kubectl logs <pod-name>
   ```

3. **Storage Issues**
   ```bash
   kubectl get pv,pvc
   ```

## Development Workflow

1. Develop notebooks in Jupyter Lab
2. Test with Papermill locally
3. Convert to Airflow DAGs
4. Deploy Spark jobs via Operator
5. Use LocalStack for AWS testing

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
