# kindadm

Create and administer a local one or multi-node Kubernetes cluster(s) in Docker container(s) with properly configured Helm v3, Ingress Controller, MetalLB, Metrics Server, and Kubernetes Dashboard with simple interactive commands.

Optional components: Weave Scope, Docker Container Registry.

> **NOTE**: Those of you who would like to use the automation with Helm v2 - please switch to branch `helm-v2`.

## Quick Start

To create a local one or multi-node Kubernetes (K8s) cluster(s) - please run:

```bash
cd local-cluster

## Extra args are optional.
#
bash setup.sh --helm_ver=3.[x].[x]
bash kindadm.sh --nodes=[1-99] --k8s_ver=1.[x].[x]
```

To purge interactively any created cluster(s):

```bash
bash kindadm.sh --purge
```

## Helper Menu

```console
# bash kindadm.sh -h

Usage:
    --all-labelled,-al      Set labels on all K8s nodes.
    --all-tainted,-at       Set taints on all K8s nodes. A different label can be defined.
    --create-registry,-cr   Create local container registry for K8s cluster(s).
    --half-labelled,-hl     Set labels on half K8s nodes.
    --half-tainted,-ht      Set taints on half K8s nodes. A different label can be defined.
    --k8s_ver,-v            Set K8s version to be deployed.
    --list-oa,-loa          List supported optional app(s).
    --nodes,-n              Set number of K8s nodes to be created.
    --opt-apps,-oa          Deploy supported optional app(s).
    --purge,-p              Purge interactively any existing cluster(s) and related resources.
    --help,-h               Prints this message.
Example:
    bash kindadm.sh -n=2 -v=1.19.1 -hl='nodeType=devops' -ht -oa=weave-scope -cr
```

```console
# bash setup.sh -h

Usage:
    --helm_ver,-hv      Set Helm version to be deployed.
    --sys_wide,-sw      Install prerequisites system-wide.
    --help,-h           Prints this message.
Example:
    bash setup.sh -hv=3.3.1 -sw
```

### Supported Optional Apps

- [Weave Scope](https://www.weave.works/oss/scope/).

### Access Deployed Services

#### Kubernetes Dashboard

To access Kubernetes Dashboard from your local workstation, you must create a secure channel to your Kubernetes cluster. Run the following command:

```bash
kubectl proxy
```

Now you can access the dashboard at:

[`http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/`](
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/).

#### Weave Scope

To access Weave Scope (if deployed) from your local workstation, run the following command:

```bash
kubectl port-forward -n weave svc/weave-scope-weave-scope 80
```

Now you can access the Weave Scope Frontend at:

[`http://localhost:80`](http://localhost:80).

## Prerequisite Notes

The `setup.sh` can be used either like a true Shell script, or the commands which are part of it can be executed one by one. It depends on your preference.

It can be run multiple times. Changes are done only if needed.

By default `setup.sh` downloads and installs Docker Runtime OS package and the following binaries in self-contained `.cache` dir:

1. Linux Docker Container Runtime (`docker.io` or `docker-ce` OS pkg).
2. `kubectl` binary.
3. `helm` binary.
4. Helm plugins: `helm-diff`.
5. `helmfile` binary.
6. `kind` binary.

With `--sys_wide` flag the aforementioned binaries will be installed system-wide (in `/usr/local/bin` dir).

## Credits

My name is [Miroslav Hadzhiev](https://www.linkedin.com/in/mehadzhiev/) - a DevOps Engineer located in Sofia, Bulgaria. I'm glad that you liked my automation.

## License

GNU General Public License v2.0
