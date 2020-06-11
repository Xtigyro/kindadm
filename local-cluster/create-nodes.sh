#!/usr/bin/env bash
set -e

if [[ -z "$1" ]]; then
  printf "\nAt least no. of K8s nodes must be set. \nUse \e[32m\e[1m\"bash $0 --help\"\e[00m for details.\n"
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --nodes*|-n*)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      if [[ "$1" != *[1-9][0-9] ]] && [[ "$1" != *[1-9] ]]; then
        printf "\e[32m\n\e[1mNo. of K8s nodes must be: 1-99.\e[00m\n"
        exit 1
      fi
      NO_NODES="${1#*=}"
      ;;
    --k8s_ver*|-v*)
      if [[ "$1" != *=* ]]; then shift; fi
      if [[ "$1" != *1.*.* ]]; then
        printf "\e[32m\n\e[1mIncompatible K8s node ver.\nCorrect syntax: 1.[number].[number]\e[00m\n"
        exit 2
      fi
      K8S_VER="${1#*=}"
      ;;
    --help|-h)
      printf "\nUsage:\e[32m\e[1m\n    --k8s_ver,-v       Set K8s version to be deployed.\n    --nodes,-n          Set number of K8s nodes to be created.\n    --help,-h           Prints this message.\n\e[00mExample:\e[32m\e[1m\n    bash $0 -n=1 -v=1.18.2\e[00m\n" # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "\e[32m\n\e[1mError: Invalid argument\e[00m\n"
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
