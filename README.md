# kindadm

Create and administer a local one or multi-node Kubernetes cluster(s) in Docker container(s) with properly configured Helm v2 (optionally `tillerless`), Ingress Controller, MetalLB, Metrics Server, and Kubernetes Dashboard with simple interactive commands.

## Quick Start

To create a local one or multi-node Kubernetes (K8s) cluster - please run:

```bash
cd local-cluster

# Extra args are optional.
bash setup.sh --helm_ver=2.[x].[x]
bash kindadm.sh --nodes=[1-99] --k8s_ver=1.[x].[x]
```

To purge interactively any created cluster(s):

```bash
bash kindadm.sh --purge
```

## Helper Menu

```console
Usage:
    --all-labelled,-al      Set labels on all K8s nodes.
    --all-tainted,-at       Set taints on all K8s nodes. A different label can be defined.
    --create-registry,-cr   Create local container registry for K8s cluster.
    --half-labelled,-hl     Set labels on half K8s nodes.
    --half-tainted,-ht      Set taints on half K8s nodes. A different label can be defined.
    --k8s_ver,-v            Set K8s version to be deployed.
    --list-oa,-loa          List supported optional app(s).
    --nodes,-n              Set number of K8s nodes to be created.
    --opt-apps,-oa          Deploy supported optional app(s).
    --purge,-p              Purges interactively any existing clusters and temp configs.
    --help,-h               Prints this message.
Example:
    bash kindadm.sh -n=2 -v=1.19.1 -hl='nodeType=devops' -ht -oa=weave-scope -cr
```

```console
# bash setup.sh -h

Usage:
    --helm_ver,-hv      Set Helm version to be deployed.
    --help,-h           Prints this message.
Example:
    bash setup.sh -hv=2.16.12
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

The `setup.sh` can be used either like a true Shell script, or the commands which are part of it can be executed one by one. It depends on your preference.

`setup.sh` downloads and installs the following software:

1. Linux Docker container runtime (`docker.io` or `docker-ce` pkg depending on your OS).
2. `kubectl` binary.
3. `helm` binary.
4. Helm plugins: `helm-diff` and `tiller`.
5. `helmfile` binary.
6. `kind` binary.

It can be run multiple times.

## Credits

My name is [Miroslav Hadzhiev](https://www.linkedin.com/in/mehadzhiev/) - a DevOps Engineer located in Sofia, Bulgaria. I'm glad that you liked my automation.

## License

GNU General Public License v2.0
