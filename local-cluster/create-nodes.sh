#!/usr/bin/env bash
set -e

while [ $# -gt 0 ]; do
  case "$1" in
    --nodes*|-n*)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      if [[ "$1" != *[1-9][0-9] ]] && [[ "$1" != *[1-9] ]]; then
        echo -e "\e[32m\n\e[1mNo. of K8s nodes must be: 1-99.\e[00m"
        exit 1
      fi
      NO_NODES="${1#*=}"
      ;;
    --k8s_ver*|-k*)
      if [[ "$1" != *=* ]]; then shift; fi
      if [[ "$1" != *.*.* ]]; then
        echo -e "\e[32m\n\e[1mWrong K8s node version. E.g.: 1.18.2\e[00m"
        exit 2
      fi
      K8S_VER="${1#*=}"
      ;;
    --helm_ver*|-h*)
      if [[ "$1" != *=* ]]; then shift; fi
      HELM_VER="${1#*=}"
      ;;
    --help|-h)
      printf "Meaningful help message" # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "Error: Invalid argument\n"
      exit 1
      ;;
  esac
  shift
done

echo "${NO_NODES}"
echo "${K8S_VER}"
exit 0

KIND_CFG="./kind-cfg.yaml"
KIND_CTRL_CFG=$'\n  - role: control-plane\n    image: kindest/node:'"${K8S_VER}"$'\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
KIND_WRKR_CFG=$'\n  - role: worker\n    image: kindest/node:'"${K8S_VER}"$'\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'

# Adjust the kINd config
cp "${KIND_CFG}"{,.backup}
if [ "${NO_NODES}" == 1 ]; then
  NO_NODES_CREATE="$((${NO_NODES} - 1))"
else
  NO_NODES_CREATE="${NO_NODES}"
fi
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
