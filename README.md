# deploy-kubernetes-kind

## A Local One or Multi-Node K8s Cluster Gunned for Development

To create a local K8s cluster in Docker container(s) with properly configured Helm v3, Ingress Controller, MetalLB, and Metrics Server - please run:

```bash
cd local-cluster
bash prerequisites-cmds.sh --helm_ver=3.[x].[x]             # Helm ver. is optional.
bash create-cluster.sh --nodes=[1-99] --k8s_ver=1.[x].[x]   # Only no. of K8s nodes is mandatory.
```

## Prerequisite Notes

The `prerequisites-cmds.sh` can be used either like a true Shell script, or the commands which are part of it can be executed one by one. It depends on your preference.

It downloads and installs the following software:

1. Linux Docker container runtime (`docker.io` or `docker-ce` pkg depending on your OS).
2. `kubectl` binary.
3. `helm` binary.
4. Helm plugins: `helm-diff`.
5. `kind` binary.

> **NOTE**: Those of you who would like to use the automation with Helm v2 - please switch to branch `helm-v2`.
