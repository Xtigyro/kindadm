#!/usr/bin/env bash
set -e

LIGHT_GREEN='\033[1;32m'
NC='\033[0m' # No Color

if [[ -z "$1" ]]; then
  printf "\nAt least no. of K8s nodes must be set. \nUse ${LIGHT_GREEN}\"bash $0 --help\"${NC} for details.\n"
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --nodes=*|-n=*)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      if [[ "$1" != *=[1-9] ]] && [[ "$1" != *=[1-9][1-9] ]]; then
        printf "\nNo. of K8s nodes must be: ${LIGHT_GREEN}1-99${NC}.\n"
        exit 1
      fi
      NO_NODES="${1#*=}"
      ;;
    --k8s_ver=*|-v=*)
      if [[ "$1" != *=* ]]; then shift; fi
      if [[ "$1" != *=1.*.* ]]; then
        printf "\nIncompatible K8s node ver.\nCorrect syntax/version: ${LIGHT_GREEN}1.[x].[x]${NC}\n"
        exit 2
      fi
      K8S_VER="${1#*=}"
      ;;
    --help|-h)
      printf "\nUsage:${LIGHT_GREEN}\n    --k8s_ver,-v       Set K8s version to be deployed.\n    --nodes,-n          Set number of K8s nodes to be created.\n    --help,-h           Prints this message.\n${NC}Example:${LIGHT_GREEN}\n    bash $0 -n=1 -v=1.18.2${NC}\n" # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "\nError: ${LIGHT_GREEN}Invalid argument${NC}\n"
      exit 3
      ;;
  esac
  shift
done

KIND_CFG="./kind-cfg.yaml"

if [[ -z "$K8S_VER" ]]; then
  KIND_CTRL_CFG=$'\n  - role: control-plane\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
  KIND_WRKR_CFG=$'\n  - role: worker\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
else
  KIND_CTRL_CFG=$'\n  - role: control-plane\n    image: kindest/node:v'"${K8S_VER}"$'\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
  KIND_WRKR_CFG=$'\n  - role: worker\n    image: kindest/node:v'"${K8S_VER}"$'\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
fi

# Adjust the kINd config
cp "${KIND_CFG}"{,.backup}
if [ "${NO_NODES}" == 1 ]; then
  NO_NODES_CREATE="$((${NO_NODES} - 1))"
else
  NO_NODES_CREATE="${NO_NODES}"
fi
echo -e "${KIND_CTRL_CFG}" >> "${KIND_CFG}"
for (( i=0; i<"${NO_NODES_CREATE}"; ++i));
  do
    echo -e "${KIND_WRKR_CFG}" >> "${KIND_CFG}"
  done
# Create kINd cluster
kind create cluster --config "${KIND_CFG}" --name kind-"${NO_NODES}"
# Revert the kINd config
yes | mv "${KIND_CFG}.backup" "${KIND_CFG}"
# Adjust Tiller K8s permissions
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
# Init Helm
helm init --service-account tiller
# Deploy desired svc-s
helmfile -f ./helmfile.yaml apply > /dev/null
# Get node names
CLUSTER_WRKS=$(kubectl get nodes | tail -n +2 | cut -d' ' -f1)
IFS=$'\n' CLUSTER_WRKS=(${CLUSTER_WRKS})
# Put node labels
for ((i=0;i<="${#CLUSTER_WRKS[@]}";i++));
  do
    if [ -n "${CLUSTER_WRKS[i]}" ] ; then
      kubectl label node "${CLUSTER_WRKS[i]}" nodeType=devops
    else
      break
    fi
  done
# Taint the node
# kubectl taint node -l nodeType=devops nodeType=devops:NoExecute
