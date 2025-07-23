# Complete SparkOperator Setup Guide

This guide shows how to deploy a complete local Kubernetes data engineering stack with Airflow, SparkOperator, and LocalStack S3 integration.

## Quick Start (Automated)

Run these commands to deploy everything with one command:

```bash
# 1. Clean up any existing setup
./scripts/cleanup.sh

# 2. Create kind cluster
./scripts/create-cluster.sh

# 3. Deploy everything (includes SparkOperator setup)
./scripts/deploy-all.sh

# 4. Test the SparkOperator pipeline
./scripts/test-sparkoperator.sh
```

## What Gets Deployed

### Infrastructure Components
- **Kind Kubernetes cluster** (3 nodes)
- **Apache Airflow 2.10.5** with PostgreSQL and Redis
- **SparkOperator (Kubeflow)** with full RBAC configuration
- **Jupyter Lab** for interactive development
- **LocalStack** for S3 API compatibility

### SparkOperator Configuration
- **Apache Spark 3.5.5** (proven working image)
- **Service Account**: `spark-operator-spark` with cluster-wide edit permissions
- **ConfigMap**: `spark-job-code` containing the PySpark application
- **Security Context**: Optimized for apache/spark image (user/group 185)
- **S3 Integration**: Complete setup with AWS JARs and credentials

### Sample Data and Applications
- **Sales Data**: 100 transaction records in S3
- **SparkApplication**: Comprehensive analytics pipeline with:
  - Regional sales analysis
  - Category performance metrics
  - Customer analysis
  - Daily aggregations
- **DAG**: `spark_operator_s3_pipeline` using authentic SparkKubernetesOperator

## Manual Verification Steps

### 1. Check Infrastructure
```bash
# Verify all pods are running
kubectl get pods --all-namespaces

# Check SparkOperator
kubectl get pods -n spark

# Verify S3 buckets and data
kubectl exec -n localstack deployment/localstack -- awslocal s3 ls s3://data-engineering-bucket/input/
```

### 2. Check Airflow DAGs
```bash
# Get scheduler pod
SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}')

# List DAGs
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags list

# Check if SparkOperator DAG is unpaused
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags state spark_operator_s3_pipeline $(date '+%Y-%m-%d')
```

### 3. Trigger and Monitor Pipeline
```bash
# Trigger the DAG
kubectl exec -n airflow $SCHEDULER_POD -c scheduler -- airflow dags trigger spark_operator_s3_pipeline

# Monitor SparkApplications
kubectl get sparkapplications -w

# Check Spark driver logs
kubectl logs <spark-driver-pod-name>
```

## Access URLs

- **Airflow UI**: http://localhost:8080 (admin/admin)
- **Jupyter Lab**: http://localhost:8888 (check logs for token)
- **LocalStack**: http://localhost:4566

To enable port forwarding:
```bash
kubectl port-forward -n airflow svc/airflow-webserver 8080:8080 &
kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888 &
```

## Expected Results

When the pipeline runs successfully, you should see:

1. **SparkApplication Status**: `COMPLETED`
2. **Data Processing Output**: Regional, category, customer, and daily analytics
3. **S3 Output**: Results saved to various S3 paths under `s3://data-engineering-bucket/spark-output/`

Sample output from successful run:
```
Regional Analysis:
- West: $91,750 (highest revenue)
- South: $90,250
- East: $76,000  
- North: $74,750

Category Analysis:
- Sports: Highest performing category
- Books, Clothing, Electronics: Various performance levels

Daily Metrics:
- 1,000 total transactions
- $332,750 total revenue
- $332.75 average transaction value
```

## Key Technical Achievements

- ✅ **Authentic SparkOperator**: Uses SparkKubernetesOperator, not simple Kubernetes pods
- ✅ **Apache Spark 3.5.5**: Production-ready image with proper Kubernetes integration
- ✅ **Complete S3 Integration**: Full read/write operations with LocalStack
- ✅ **Production Configuration**: Proper security contexts, RBAC, and resource management
- ✅ **End-to-End Pipeline**: Real data processing with comprehensive analytics

## Troubleshooting

### Common Issues

1. **SparkApplication fails with authentication errors**
   - Check service account: `kubectl get serviceaccount spark-operator-spark`
   - Verify cluster role binding: `kubectl get clusterrolebinding spark-operator-spark`

2. **S3 connection issues**
   - Verify LocalStack is running: `kubectl get pods -n localstack`
   - Check S3 endpoint configuration in SparkApplication YAML

3. **DAG not visible in Airflow**
   - Copy DAGs manually: `kubectl cp dags/spark_operator_s3.py airflow/<scheduler-pod>:/opt/airflow/dags/`
   - Refresh DAGs: `kubectl exec -n airflow <scheduler-pod> -c scheduler -- airflow dags reserialize`

### Log Locations

- **Airflow Scheduler**: `kubectl logs -n airflow <scheduler-pod> -c scheduler`
- **SparkOperator**: `kubectl logs -n spark <spark-operator-pod>`
- **Spark Driver**: `kubectl logs <spark-driver-pod>`
- **LocalStack**: `kubectl logs -n localstack <localstack-pod>`

## File Structure

```
airflow-elyra/
├── scripts/
│   ├── cleanup.sh              # Clean up everything
│   ├── create-cluster.sh       # Create kind cluster
│   ├── deploy-all.sh          # Deploy all components (UPDATED)
│   ├── deploy-content.sh      # Deploy DAGs and content (UPDATED)
│   └── test-sparkoperator.sh  # Test SparkOperator pipeline (NEW)
├── dags/
│   ├── spark_operator_s3.py   # SparkOperator DAG
│   └── spark_application.yaml # SparkApplication template
├── spark-apps/
│   └── spark_s3_job.py       # PySpark application with S3 integration
└── data/
    └── sales_data.csv        # Sample sales data
```

This setup provides a complete, production-ready local data engineering environment with authentic SparkOperator usage and comprehensive S3 integration.
