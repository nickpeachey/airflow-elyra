# GitHub DAG Synchronization Setup

## Overview
Your Airflow deployment is now configured to automatically synchronize DAGs from your GitHub repository every 60 seconds. This means you no longer need to manually copy DAG files - they will be automatically pulled from GitHub.

## Repository Configuration
- **Repository URL**: https://github.com/nickpeachey/airflow-elyra
- **Branch**: main (default)
- **Sync Interval**: 60 seconds
- **DAG Location**: DAGs should be in the `dags/` directory of your repository

## How It Works
1. The Airflow scheduler pod runs a `git-sync` sidecar container
2. This container clones your GitHub repository every 60 seconds
3. DAGs from the repository are mounted into the Airflow DAG folder
4. Airflow automatically detects and loads new/updated DAGs

## Key Benefits
- 🔄 **Automatic Updates**: DAGs are updated without redeployment
- 🚀 **Faster Deployment**: No need to rebuild or restart Airflow
- 📝 **Version Control**: Full Git history for your DAGs
- 👥 **Team Collaboration**: Multiple developers can contribute DAGs

## Commands for Managing GitHub Sync

### Check Sync Status
```bash
./scripts/check-git-sync.sh
```

### View Git Sync Logs
```bash
# Get scheduler pod name
SCHEDULER_POD=$(kubectl get pods -n airflow -l component=scheduler,app=airflow -o jsonpath='{.items[0].metadata.name}')

# View git-sync container logs
kubectl logs -n airflow "$SCHEDULER_POD" -c git-sync --tail=50
```

### Verify DAGs are Synced
```bash
# List files in the git-sync volume
kubectl exec -n airflow "$SCHEDULER_POD" -c scheduler -- find /opt/airflow/dags/repo -name "*.py" -type f

# List Airflow DAGs
kubectl exec -n airflow "$SCHEDULER_POD" -c scheduler -- airflow dags list
```

## Repository Structure
Your GitHub repository should have this structure:
```
airflow-elyra/
├── dags/                    # Airflow DAGs (synced automatically)
│   ├── spark_operator_s3_pipeline.py
│   └── other_dag_files.py
├── notebooks/               # Jupyter notebooks (deployed via scripts)
│   ├── data_processing.ipynb
│   └── analysis.ipynb
├── scripts/                 # Deployment scripts
└── helm/                    # Kubernetes configurations
```

## Configuration Files
- **Git Sync Config**: `helm/airflow-values-git-sync.yaml`
- **Connection Setup**: `scripts/configure-git-sync.sh`
- **Deployment Script**: `scripts/deploy-all.sh` (updated for Git sync)

## Troubleshooting

### DAGs Not Appearing
1. Check git-sync logs: `kubectl logs -n airflow $SCHEDULER_POD -c git-sync`
2. Verify repository access (public repo should work automatically)
3. Ensure DAGs are in the `dags/` directory of your repository
4. Wait up to 60 seconds for the next sync cycle

### Git Sync Container Issues
1. Check pod status: `kubectl describe pod -n airflow $SCHEDULER_POD`
2. Look for git-sync container in the pod description
3. Verify the repository URL in the Helm values

### Manual Sync Trigger
If you need to force a sync immediately:
```bash
# Restart the scheduler pod (will trigger immediate git clone)
kubectl delete pod -n airflow -l component=scheduler,app=airflow
```

## Migration from Manual DAGs
The system has been updated to use GitHub sync instead of manual DAG copying:
- ✅ `deploy-all.sh` now uses `airflow-values-git-sync.yaml`
- ✅ `deploy-content.sh` only handles notebooks (DAGs come from Git)
- ✅ S3 and Kubernetes connections are automatically configured
- ✅ Git sync status can be monitored with `check-git-sync.sh`

## Next Steps
1. Commit your DAGs to the GitHub repository in the `dags/` directory
2. Push changes to the main branch
3. Wait up to 60 seconds for Airflow to sync the changes
4. Check the Airflow UI to see your updated DAGs
