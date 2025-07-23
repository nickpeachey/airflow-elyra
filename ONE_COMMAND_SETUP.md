# 🚀 One-Command Data Engineering Stack

Deploy a complete local Kubernetes data engineering environment with a single command!

## Quick Start

```bash
# Clone/navigate to the project directory
cd airflow-elyra

# Run the ONE command that does everything
./scripts/deploy-everything.sh
```

That's it! ✨

## What You Get

- **Kind Kubernetes cluster** (3 nodes)
- **Apache Airflow 2.10.5** with PostgreSQL & Redis
- **SparkOperator (Kubeflow)** with authentic SparkKubernetesOperator
- **Apache Spark 3.5.5** with complete S3 integration
- **Jupyter Lab** for interactive development
- **LocalStack** with S3 API compatibility
- **Sample data** and working analytics pipeline
- **Complete RBAC** configuration

## Prerequisites

Make sure you have these tools installed:
- [Docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)

## After Deployment

1. **Start port forwarding** (in separate terminals):
   ```bash
   kubectl port-forward -n airflow svc/airflow-webserver 8080:8080
   kubectl port-forward -n jupyter svc/jupyter-lab-service 8888:8888
   ```

2. **Access the UIs**:
   - Airflow: http://localhost:8080 (admin/admin)
   - Jupyter: http://localhost:8888 (get token from logs)

3. **The SparkOperator pipeline is ready**:
   - DAG: `spark_operator_s3_pipeline`
   - Uses authentic SparkKubernetesOperator
   - Processes real sales data with S3 integration

## Advanced Usage

```bash
# For unattended deployment (no prompts)
AUTO_YES=true ./scripts/deploy-everything.sh

# Test the SparkOperator pipeline
./scripts/test-sparkoperator.sh

# Clean up everything
./scripts/cleanup.sh

# Redeploy only DAGs/content
./scripts/deploy-content.sh
```

## What's Different Here?

This setup provides:
- ✅ **Authentic SparkOperator** (not simple Kubernetes jobs)
- ✅ **Production-ready configuration** with proper RBAC and security
- ✅ **Complete S3 integration** with LocalStack
- ✅ **Real data processing** with comprehensive analytics
- ✅ **One-command deployment** that just works

## Troubleshooting

If something goes wrong:
1. Check that Docker is running
2. Ensure all prerequisites are installed
3. Run the cleanup script and try again
4. Check the detailed setup guide: `SPARKOPERATOR_SETUP.md`

## File Structure

```
airflow-elyra/
├── scripts/
│   ├── deploy-everything.sh   # 🎯 THE ONLY SCRIPT YOU NEED
│   ├── cleanup.sh
│   ├── create-cluster.sh
│   ├── deploy-all.sh
│   ├── deploy-content.sh
│   └── test-sparkoperator.sh
├── dags/
│   ├── spark_operator_s3.py
│   └── spark_application.yaml
├── spark-apps/
│   └── spark_s3_job.py
└── data/
    └── sales_data.csv
```

---

**Ready to get started?** Just run: `./scripts/deploy-everything.sh` 🚀
