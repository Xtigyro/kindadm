#!/usr/bin/env bash
set -e

LIGHT_GREEN='\033[1;32m'
LIGHT_RED='\033[1;31m'
NC='\033[0m'   # No Color
KIND_CFG="$(<./templates/kind-base-config.yaml)"   # base config file
K8S_CLUSTERS="$(kind get clusters 2>/dev/null | tr '\n' ' ' | sed 's/[[:blank:]]*$//')"
SUPPORTED_OPT_APPS="$(ls -d helmfiles/apps/optional/*/ | cut -f4 -d'/')"

if [[ -z "$1" ]]; then
  printf "\nAt least no. of K8s nodes must be set. \nUse ${LIGHT_GREEN}\"bash $0 --help\"${NC} for details.\n"
  exit 1
fi

# predefined functions
function contains_string {
  local list="$1"
  local item="$2"
  if [[ "$list" =~ (^|[[:space:]])"$item"($|[[:space:]]) ]]; then
    # yes, list includes item
    result=0
  else
    result=1
  fi
  return "$result"
}

function contains_strings_from_strings {
  local list_a="$1"
  local list_b="$2"
  for str in "$list_a"; do
    if [[ "$list_b" =~ (^|,)"$str"(,|$) ]]; then
      # yes, list includes item
      result=0
    else
      result=1
      break
    fi
  done
  return "$result"
}

function purge_clusters {
  select choice in "ALL_CLUSTERS" "PER_CLUSTER"; do
  case "$choice" in
    ALL_CLUSTERS) echo "$choice";
    IFS='\n' declare -g clusters=(${K8S_CLUSTERS});
    break;;
    PER_CLUSTER) echo "$choice";
    echo "Which cluster to purge?";
    read -p "[ ${K8S_CLUSTERS} ]: " K8S_CLUSTER;
    if ! `contains_string "${K8S_CLUSTERS}" "$K8S_CLUSTER"`; then
      echo "Invalid cluster name."
      exit 3
    fi
    declare -g clusters=("$K8S_CLUSTER");
    break;;
    *) echo "'ALL_CLUSTERS' or 'PER_CLUSTER' must be chosen.";
    exit 4;
    break;;
  esac
  done
}

while [ $# -gt 0 ]; do
  case "$1" in
    --nodes=*|-n=*)
      if [[ "$1" != *=[1-9] ]] && [[ "$1" != *=[1-9][1-9] ]]; then
        printf "\nNo. of K8s nodes must be: ${LIGHT_GREEN}1-99${NC}.\n"
        exit 5
      fi
      NO_NODES="${1#*=}"
      ;;
    --all-labelled=*|-al=*)
      NODE_LABEL="${1#*=}"
      COEFFICIENT_LABEL=1
      ;;
    --half-labelled=*|-hl=*)
      NODE_LABEL="${1#*=}"
      COEFFICIENT_LABEL=0.5
      ;;
    --all-tainted=*|-at=*|--all-tainted|-at)
      if [[ "$1" == *=* ]]; then NODE_TAINT_LABEL="${1#*=}"; fi
      COEFFICIENT_TAINT=1
      ;;
    --half-tainted=*|-ht=*|--half-tainted|-ht)
      if [[ "$1" == *=* ]]; then NODE_TAINT_LABEL="${1#*=}"; fi
      COEFFICIENT_TAINT=0.5
      ;;
    --opt-apps=*|-oa=*)
      if [[ "$1" == *=all ]]; then
        OPT_APPS=all
      else
        OPT_APPS="${1#*=}"
        if ! `contains_strings_from_strings "$SUPPORTED_OPT_APPS" "$OPT_APPS"`; then
          printf "\nSupported optional apps (comma-separated): ${LIGHT_GREEN}"$SUPPORTED_OPT_APPS"${NC}.\n"
          exit 6
        fi
      fi
      ;;
    --k8s_ver=*|-v=*)
      if [[ "$1" != *=1.*.* ]]; then
        printf "\nIncompatible K8s node ver.\nCorrect syntax/version: ${LIGHT_GREEN}1.[x].[x]${NC}\n"
        exit 7
      fi
      K8S_VER="${1#*=}"
      ;;
    --purge|-p)
      purge_clusters
      for ((i=0;i<"${#clusters[@]}";i++)); do
          kind delete cluster --name "${clusters[i]}"
      done
      printf "\n${LIGHT_GREEN}Clusters left:${NC}\n"
      kind get clusters
      exit 0
      ;;
    --list-oa|-loa)
        printf "\nList of supported optional apps:\
        \n    ${LIGHT_GREEN}$SUPPORTED_OPT_APPS${NC}\n"
      exit 0
      ;;
    --help|-h)
      printf "\nUsage:\
        \n    ${LIGHT_GREEN}--k8s_ver,-v${NC}         Set K8s version to be deployed.\
        \n    ${LIGHT_GREEN}--nodes,-n${NC}           Set number of K8s nodes to be created.\
        \n    ${LIGHT_GREEN}--all-labelled,-al${NC}   Set labels on all K8s nodes.\
        \n    ${LIGHT_GREEN}--half-labelled,-hl${NC}  Set labels on half K8s nodes.\
        \n    ${LIGHT_GREEN}--all-tainted,-at${NC}    Set taints on all K8s nodes. A different label can be defined.\
        \n    ${LIGHT_GREEN}--half-tainted,-ht${NC}   Set taints on half K8s nodes. A different label can be defined.\
        \n    ${LIGHT_GREEN}--purge,-p${NC}           Purges interactively any existing clusters and temp configs.\
        \n    ${LIGHT_GREEN}--opt-apps,-oa${NC}       Deploy supported optional app(s).\
        \n    ${LIGHT_GREEN}--list-oa,-loa${NC}       List supported optional app(s).\
        \n    ${LIGHT_GREEN}--help,-h${NC}            Prints this message.\
        \nExample:\n    ${LIGHT_GREEN}bash $0 -n=2 -v=1.19.1 -hl='nodeType=devops' -ht -oa=weave-scope${NC}\n"   # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "\nError: ${LIGHT_GREEN}Invalid argument${NC}\n"
      exit 8
      ;;
  esac
  shift
done

if [[ -z "$K8S_VER" ]]; then
  KIND_CTRL_CFG=$'\n  - role: control-plane\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
  KIND_WRKR_CFG=$'\n  - role: worker\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
else
  KIND_CTRL_CFG=$'\n  - role: control-plane\n    image: kindest/node:v'"${K8S_VER}"$'\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
  KIND_WRKR_CFG=$'\n  - role: worker\n    image: kindest/node:v'"${K8S_VER}"$'\n    extraMounts:\n      - hostPath: /var/run/docker.sock\n        containerPath: /var/run/docker.sock'
fi

# Adjust KinD config
## Calculate no. of nodes
if [ "${NO_NODES}" == 1 ]; then
  NO_NODES_CREATE="$((${NO_NODES} - 1))"
else
  NO_NODES_CREATE="${NO_NODES}"
fi
## Create new KinD config
KIND_CFG="${KIND_CFG}${KIND_CTRL_CFG}"
for (( i=0; i<"${NO_NODES_CREATE}"; ++i));
  do
    KIND_CFG="${KIND_CFG}${KIND_WRKR_CFG}"
  done

# Create KinD cluster
kind create cluster --config <(echo "${KIND_CFG}") --name kind-"${NO_NODES}"

# Adjust Tiller K8s permissions
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

# Init Helm
helm init --service-account tiller

# Deploy default apps
helmfile -f ./helmfiles/apps/default/helmfile.yaml apply > /dev/null

# Deploy conditionally optional apps
if [[ ! -z "$OPT_APPS" ]]; then
  if [[ "$OPT_APPS" == "all" ]]; then
    helmfile -f ./helmfiles/apps/optional/helmfile.yaml apply > /dev/null
  else
    for app in "$OPT_APPS"; do
      helmfile -f ./helmfiles/apps/optional/"$app"/helmfile.yaml apply > /dev/null
    done
  fi
fi

# Deploy Kubernetes Dashboard Admin ClusterRoleBinding
kubectl apply -f ./templates/k8s-dashboard-rolebinding.yaml

# Get node names
CLUSTER_WRKS=$(kubectl get nodes | tail -n +2 | cut -d' ' -f1)
IFS=$'\n' CLUSTER_WRKS=(${CLUSTER_WRKS})

# Put node labels
if [[ ! -z "$COEFFICIENT_LABEL" ]]; then
  NO_NODES_LABELLED="$(bc -l <<<"${#CLUSTER_WRKS[@]} * $COEFFICIENT_LABEL" | awk '{printf("%d\n",$1 - 0.5)}')"
  for ((i=1;i<="$NO_NODES_LABELLED";i++));
    do
      kubectl label node "${CLUSTER_WRKS[i]}" "$NODE_LABEL"
    done
fi

# Taint nodes with "NoExecute"
if [[ ! -z "$COEFFICIENT_TAINT" ]]; then
  NO_NODES_TAINTED="$(bc -l <<<"${#CLUSTER_WRKS[@]} * $COEFFICIENT_TAINT" | awk '{printf("%d\n",$1 - 0.5)}')"
  for ((i=1;i<="$NO_NODES_TAINTED";i++));
    do
      if [[ ! -z "$NODE_LABEL" ]] && [[ -z "$NODE_TAINT_LABEL" ]] ; then
        kubectl taint node "${CLUSTER_WRKS[i]}" "$NODE_LABEL":NoExecute
      else
        kubectl taint node "${CLUSTER_WRKS[i]}" "$NODE_TAINT_LABEL":NoExecute
      fi
    done
fi
