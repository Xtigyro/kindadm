# kindadm

Create and administer a local one or multi-node Kubernetes cluster(s) in Docker container(s) with properly configured Helm v3, Ingress Controller, MetalLB, Metrics Server, and Kubernetes Dashboard with simple interactive commands.

> **NOTE**: Those of you who would like to use the automation with Helm v2 - please switch to branch `helm-v2`.

## Demo

![gif](demo.gif)

## Quick Start

To create a local one or multi-node Kubernetes (K8s) cluster - please run:

```bash
cd local-cluster

# Extra args are optional.
bash prerequisites-cmds.sh --helm_ver=3.[x].[x]
bash create-cluster.sh --nodes=[1-99] --k8s_ver=1.[x].[x]
```

To purge interactively any created cluster(s):

```bash
bash create-cluster.sh --purge
```

## Helper Menu

```console
# bash create-cluster.sh -h

Usage:
    --k8s_ver,-v         Set K8s version to be deployed.
    --nodes,-n           Set number of K8s nodes to be created.
    --all-labelled,-al   Set labels on all K8s nodes.
    --half-labelled,-hl  Set labels on half K8s nodes.
    --all-tainted,-at    Set taints on all K8s nodes. A different label can be defined.
    --half-tainted,-ht   Set taints on half K8s nodes. A different label can be defined.
    --purge,-p           Purges interactively any existing clusters and temp configs.
    --opt-apps,-oa       Deploy supported optional app(s).
    --list-oa,-loa       List supported optional app(s).
    --help,-h            Prints this message.
Example:
    bash create-cluster.sh -n=2 -v=1.19.1 -hl='nodeType=devops' -ht -oa=weave-scope
```

```console
# bash prerequisites-cmds.sh -h

Usage:
    --helm_ver,-hv      Set Helm version to be deployed.
    --help,-h           Prints this message.
Example:
    bash prerequisites-cmds.sh -hv=3.3.1
```

### Supported Optional Apps

- [Weave Scope](https://www.weave.works/oss/scope/).

### Access Kubernetes Dashboard

To access Dashboard from your local workstation, you must create a secure channel to your Kubernetes cluster. Run the following command:

```bash
kubectl proxy
```

Now you can access the Kubernetes Dashboard at:

[`http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/`](
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/).

## Prerequisite Notes

The `prerequisites-cmds.sh` can be used either like a true Shell script, or the commands which are part of it can be executed one by one. It depends on your preference.

`prerequisites-cmds.sh` downloads and installs the following software:

1. Linux Docker container runtime (`docker.io` or `docker-ce` pkg depending on your OS).
2. `kubectl` binary.
3. `helm` binary.
4. Helm plugins: `helm-diff`.
5. `helmfile` binary.
6. `kind` binary.

It can be run multiple times and be used even just to update to the latest stable versions of `kubectl`, `helm-diff`, and `helmfile`.

## Credits

My name is [Miroslav Hadzhiev](https://www.linkedin.com/in/mehadzhiev/) - a DevOps Engineer located in Sofia, Bulgaria. I'm glad that you liked my automation.

## License

GNU General Public License v2.0
