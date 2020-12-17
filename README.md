# terraform-kubernetes-gke-nfs

Creates GCE Regional disk, mounts it to NFS statefulset and creates multiple volumes mountable as ReadWriteMany (RWX).

Please do not run a database on it.  

## Basic Usage

```hcl
module "airflow_nfs" {
  source  = "kiwicom/gke-nfs/kubernetes"
  version = "0.1.0"

  name      = "nfs"
  namespace = "example"

  request_cpu    = "12"
  request_memory = "12Gi"
  limit_cpu      = "24"
  limit_memory   = "12Gi"

  volumes = {
    "nfs-airflow-dags" = 10
    "nfs-airflow-logs" = 10
  }
}
```

```yaml
# just an "illustration" yaml - it doesn't work
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-with-shared-disk
  namespace: example
  labels:
    app: scheduler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scheduler
  template:
    metadata:
      labels:
        app: scheduler
    spec:
      containers:
      - name: scheduler
        image: airflow:latest
        args: ["scheduler"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /usr/local/airflow/dags
          name: airflow-dags
        - mountPath: /usr/local/airflow/logs
          name: airflow-logs
      volumes:
      - name: airflow-dags
        persistentVolumeClaim:
          claimName: nfs-airflow-dags
      - name: airflow-logs
        persistentVolumeClaim:
          claimName: nfs-airflow-logs
```

## Advanced Usage

You can optionally specify `tolerations` or `node_selector_terms` blocks for better schedule management.

`tolerations`: use key-value pair to specify `key` and `value` of `toleration`. Other arguments are set like this `operator = "Equal"` and `effect = "NoSchedule"`.

`node_selector_terms`: use key-value pair to specify labels of your nodes, which you can get by cmd `kubectl get nodes --show-labels`. This will be used to create node affinity.

```hcl
module "airflow_nfs" {
  source  = "kiwicom/gke-nfs/kubernetes"
  version = "0.1.0"

  name      = "nfs"
  namespace = "example"

  request_cpu    = "12"
  request_memory = "12Gi"
  limit_cpu      = "24"
  limit_memory   = "12Gi"

  volumes = {
    "nfs-airflow-dags" = 10
    "nfs-airflow-logs" = 10
  }
  
  tolerations = { 
    "dedicated" = "nfs-server"
  }

  node_selector_terms = {
    "pool_name" = "nfs_pool"
  }
}
```

```yaml
# just an "illustration" yaml - it doesn't work
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-with-shared-disk
  namespace: example
  labels:
    app: scheduler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scheduler
  template:
    metadata:
      labels:
        app: scheduler
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: pool_name
                operator: In
                values:
                - nfs_pool
      containers:
      - name: scheduler
        image: airflow:latest
        args: ["scheduler"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /usr/local/airflow/dags
          name: airflow-dags
        - mountPath: /usr/local/airflow/logs
          name: airflow-logs
      tolerations:
      - effect: NoSchedule
        key: dedicated
        operator: Equal
        value: nfs-server
      volumes:
      - name: airflow-dags
        persistentVolumeClaim:
          claimName: nfs-airflow-dags
      - name: airflow-logs
        persistentVolumeClaim:
          claimName: nfs-airflow-logs
```
