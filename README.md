# deploy-kubernetes-kind

## A Local One or Multi-Node K8s Cluster Gunned for Development

To create a local K8s cluster in Docker container(s) with properly configured Helm (optionally `tillerless`), Ingress Controller, MetalLB, and Metrics Server - please run:

```bash
cd local-cluster
bash prerequisites-cmds.sh --helm_ver=2.[x].[x]             # Helm ver. is optional.
bash create-cluster.sh --nodes=[1-99] --k8s_ver=1.[x].[x]   # Only no. of K8s nodes is mandatory.
```
