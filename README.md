# deploy-kubernetes-kind

## A Local One or Multi-Node K8s Cluster Gunned for Development

To create a local K8s cluster in Docker container(s) with properly configured Helm v3, Ingress Controller, MetalLB, and Metrics Server - please run:

```bash
cd local-cluster
bash prerequisites-cmds.sh
bash create-nodes.sh [1-99]
```

> **NOTE**: Those of you who would like to use the automation with Helm v2 - please switch to branch `helm-v2`.
