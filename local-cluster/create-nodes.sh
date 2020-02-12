#!/usr/bin/env bash
set -e

NO_NODES="${1}"
KIND_CFG="./kind-cfg.yaml"
KIND_WRKR_CFG=$'\n  - role: worker\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'

case "${NO_NODES}" in
  [1-9]|[1-9][0-9])
  ;;
  *)
  echo -e "\e[32m\n\e[1mPass the number of the desired nodes: 1-99.\e[00m"
  exit 11
  ;;
esac

# Adjust the kINd config
cp "${KIND_CFG}"{,.backup}
for (( i=0; i<$(("${NO_NODES}" - 1)); ++i));
  do
    echo -e "${KIND_WRKR_CFG}" >> "${KIND_CFG}"
  done
# Create kINd cluster
kind create cluster --config "${KIND_CFG}" --name kind-"${NO_NODES}"
# Revert the kINd config
yes | mv "${KIND_CFG}.backup" "${KIND_CFG}"
# Init Helm Client
helm init --client-only
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
