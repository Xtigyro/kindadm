# deploy-kubernetes-kind

## A Local One or Multi-Node K8s Cluster Gunned for Development

To create a local K8s cluster in Docker container(s) with properly configured Helm (optionally `tillerless`), Ingress Controller and MetalLB - please run:

```bash
cd local-cluster
bash prerequisites-cmds.sh
bash create-nodes.sh [1-99]
```
