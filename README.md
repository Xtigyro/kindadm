# deploy-kubernetes-kind

Create a local one or multi-node K8s cluster preset for development with one command.

> **NOTE**: Those of you who would like to use the automation with Helm v2 - please switch to branch `helm-v2`.

## Demo

![gif](demo.gif)

## Quick Start

To create a local K8s cluster in Docker container(s) with properly configured Helm v3, Ingress Controller, MetalLB, and Metrics Server - please run:

```bash
cd local-cluster
bash prerequisites-cmds.sh --helm_ver=3.[x].[x]             # Helm ver. is optional.
bash create-cluster.sh --nodes=[1-99] --k8s_ver=1.[x].[x]   # Only no. of K8s nodes is mandatory.
```

## Prerequisite Notes

The `prerequisites-cmds.sh` can be used either like a true Shell script, or the commands which are part of it can be executed one by one. It depends on your preference.

`prerequisites-cmds.sh` downloads and installs the following software:

1. Linux Docker container runtime (`docker.io` or `docker-ce` pkg depending on your OS).
2. `kubectl` binary.
3. `helm` binary.
4. Helm plugins: `helm-diff`.
5. `helmfile` binary.
6. `kind` binary.

## Credits

My name is [Miroslav Hadzhiev](https://www.linkedin.com/in/mehadzhiev/) - a DevOps Engineer located in Sofia, Bulgaria. I'm glad that you liked my automation.

## Licence

GNU General Public License v2.0
