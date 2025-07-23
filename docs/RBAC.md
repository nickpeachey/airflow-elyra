# RBAC Configuration Summary

This document outlines the complete Role-Based Access Control (RBAC) configuration for the data engineering stack, ensuring Airflow and Spark Operator can execute Spark Scala jobs successfully.

## Overview

The RBAC setup includes:
- **Service Accounts** for each component
- **Cluster Roles** for cluster-wide permissions
- **Roles** for namespace-specific permissions
- **Role Bindings** and **Cluster Role Bindings** to connect accounts to roles

## Service Accounts

### Airflow Service Account
- **Name**: `airflow`
- **Namespace**: `airflow`
- **Purpose**: Allows Airflow to manage Kubernetes resources and submit Spark jobs

### Spark Operator Service Account
- **Name**: `spark-operator`
- **Namespace**: `spark`
- **Purpose**: Allows Spark Operator to manage Spark applications and pods

### Spark Driver Service Account
- **Name**: `spark-driver`
- **Namespace**: `spark`
- **Purpose**: Used by Spark driver pods to manage executor pods

### Spark Executor Service Account
- **Name**: `spark-executor`
- **Namespace**: `spark`
- **Purpose**: Used by Spark executor pods (minimal permissions)

## Cluster Roles

### Airflow Cluster Role
**Permissions**:
- Core resources: `pods`, `services`, `configmaps`, `secrets`, `events`
- Apps resources: `deployments`, `replicasets`
- Batch resources: `jobs`
- Spark Operator resources: `sparkapplications`, `scheduledsparkapplications`
- Networking: `ingresses`
- Metrics: `pods`, `nodes`

**Scope**: Cluster-wide

### Spark Operator Cluster Role
**Permissions**:
- Core resources: `pods`, `services`, `configmaps`, `secrets`, `nodes`, `events`
- Apps resources: `deployments`, `replicasets`
- Extensions: `ingresses`
- RBAC: `roles`, `rolebindings`
- Spark resources: `sparkapplications`, `scheduledsparkapplications`
- Admission controllers: `mutatingadmissionconfigurations`, `validatingadmissionconfigurations`
- CRDs: `customresourcedefinitions`
- Batch: `jobs`
- Coordination: `leases`

**Scope**: Cluster-wide

## Namespace Roles

### Spark Driver Role (spark namespace)
**Permissions**:
- `pods`, `services`, `configmaps`, `persistentvolumeclaims`: full access
- `secrets`: read-only access

**Purpose**: Allows Spark drivers to create and manage executor pods

### Airflow Spark Jobs Role (spark namespace)
**Permissions**:
- Core resources: `pods`, `services`, `configmaps`, `secrets`
- Spark resources: `sparkapplications`
- Batch resources: `jobs`

**Purpose**: Allows Airflow to submit and manage Spark jobs in the spark namespace

### Airflow Jupyter Jobs Role (jupyter namespace)
**Permissions**:
- Core resources: `pods`, `services`, `configmaps`, `secrets`
- Batch resources: `jobs`

**Purpose**: Allows Airflow to run notebook jobs in the jupyter namespace

## Role Bindings

### Cluster Role Bindings
1. **airflow**: Binds `airflow` service account to `airflow` cluster role
2. **spark-operator**: Binds `spark-operator` service account to `spark-operator` cluster role

### Namespace Role Bindings
1. **spark-driver** (spark namespace): Binds `spark-driver` service account to `spark-driver` role
2. **airflow-spark-jobs** (spark namespace): Binds `airflow` service account to `airflow-spark-jobs` role
3. **airflow-jupyter-jobs** (jupyter namespace): Binds `airflow` service account to `airflow-jupyter-jobs` role

## File Structure

```
k8s/
├── airflow/
│   └── airflow-rbac.yaml          # Airflow RBAC resources
└── spark/
    └── spark-rbac.yaml            # Spark RBAC resources
```

## Deployment Order

1. **Create namespaces**:
   ```bash
   kubectl create namespace airflow
   kubectl create namespace spark
   kubectl create namespace jupyter
   ```

2. **Apply RBAC resources**:
   ```bash
   kubectl apply -f k8s/airflow/airflow-rbac.yaml
   kubectl apply -f k8s/spark/spark-rbac.yaml
   ```

3. **Deploy applications** with service account references:
   - Airflow Helm chart configured to use `airflow` service account
   - Spark Operator configured to use `spark-operator` service account
   - Spark applications configured to use `spark-driver` and `spark-executor` service accounts

## Security Principles

### Principle of Least Privilege
Each service account has only the minimum permissions required:
- **Airflow**: Can manage Kubernetes resources needed for job execution
- **Spark Operator**: Can manage Spark applications and related Kubernetes resources
- **Spark Driver**: Can create and manage executor pods within the same namespace
- **Spark Executor**: Minimal permissions (inherits from default service account)

### Namespace Isolation
- Cross-namespace access is explicitly granted only where needed
- Airflow can access `spark` and `jupyter` namespaces for job submission
- Spark applications are isolated within the `spark` namespace

### Resource Scoping
- Cluster roles are used only when cluster-wide access is necessary
- Namespace roles are preferred for namespace-specific operations
- Specific resource types and verbs are explicitly listed

## Verification

### Check Service Accounts
```bash
kubectl get serviceaccounts -n airflow
kubectl get serviceaccounts -n spark
kubectl get serviceaccounts -n jupyter
```

### Check Roles and Bindings
```bash
kubectl get clusterroles | grep -E "(airflow|spark)"
kubectl get clusterrolebindings | grep -E "(airflow|spark)"
kubectl get roles -n spark
kubectl get rolebindings -n spark
```

### Test Permissions
```bash
# Test Airflow permissions
kubectl auth can-i create pods --as=system:serviceaccount:airflow:airflow -n spark

# Test Spark Operator permissions
kubectl auth can-i create sparkapplications --as=system:serviceaccount:spark:spark-operator -n spark

# Test Spark Driver permissions
kubectl auth can-i create pods --as=system:serviceaccount:spark:spark-driver -n spark
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**:
   - Check if service account exists: `kubectl get sa <name> -n <namespace>`
   - Verify role binding: `kubectl describe rolebinding <name> -n <namespace>`
   - Test specific permission: `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<name>`

2. **Spark Job Submission Failures**:
   - Verify Spark Operator has cluster-wide permissions
   - Check if Spark CRDs are installed: `kubectl get crd | grep spark`
   - Ensure Airflow can create `sparkapplications` in spark namespace

3. **Pod Creation Failures**:
   - Check if service account is specified in pod spec
   - Verify service account has pod creation permissions
   - Ensure namespace exists and is accessible

### Debugging Commands

```bash
# View effective permissions for a service account
kubectl auth can-i --list --as=system:serviceaccount:airflow:airflow

# Describe specific role or binding
kubectl describe clusterrole airflow
kubectl describe clusterrolebinding airflow

# Check pod service account
kubectl get pod <pod-name> -o jsonpath='{.spec.serviceAccountName}'

# View role binding subjects
kubectl get rolebinding -o wide -n spark
```

## Updates and Maintenance

### Adding New Permissions
1. Update the appropriate RBAC YAML file
2. Apply changes: `kubectl apply -f k8s/<component>/<rbac-file>.yaml`
3. Verify permissions: `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<name>`

### Service Account Rotation
1. Create new service account
2. Update role bindings to reference new account
3. Update application configurations
4. Remove old service account

### Monitoring RBAC
- Regularly audit permissions with `kubectl auth can-i --list`
- Monitor for permission denied errors in application logs
- Use admission controllers to enforce RBAC policies

This RBAC configuration ensures secure and functional operation of the entire data engineering stack while maintaining the principle of least privilege.
