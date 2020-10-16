#!/usr/bin/env bash
set -ex

# default versions
HELM_VER='3.3.1'
HELM_VER_3='3.3.1'
HELM_VER_2='2.16.12'

LIGHT_GREEN='\033[1;32m'
LIGHT_RED='\033[1;31m'
NC='\033[0m'   # No Color
SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; pwd -P )"
CACHE_DIR="$SCRIPT_DIR/.cache"
EXEC_DIR="$CACHE_DIR"
KIND_CFG="$(<./templates/kind-base-config.yaml)"   # base config file
K8S_CLUSTERS="$("$EXEC_DIR"/kind get clusters 2>/dev/null | tr '\n' ' ' | sed 's/[[:blank:]]*$//')"
SUPPORTED_OPT_APPS="$(ls -d helmfiles/apps/optional/*/ | cut -f4 -d'/')"
NO_NODES='1'
REG_NAME='kind-registry'

SETUP_EXEC="$SCRIPT_DIR/bin/setup.sh"
SYS_WIDE=false

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

function create_k8s_ns {
# create required K8s namespaces for apps
  if [[ "$1" == "all" ]] && [[ ! -z "$1" ]]; then
    local k8s_ns=($(grep -r 'namespace: ' ./helmfiles/apps/optional/*/helmfile.yaml | cut -d ':' -f2 | tr -d ' '))
  elif [[ "$1" != "all" ]] && [[ ! -z "$1" ]]; then
    local k8s_ns=($(grep 'namespace: ' ./helmfiles/apps/optional/"$1"/helmfile.yaml | cut -d ':' -f2 | tr -d ' '))
  else
    local k8s_ns=($(grep -r 'namespace: ' ./helmfiles/apps/default/*/helmfile.yaml | cut -d ':' -f3 | tr -d ' '))
  fi
  local unique_k8s_ns=($(tr ' ' '\n' <<< "${k8s_ns[@]}" | tr '\n' ' '))

  for ((i=0;i<="${#unique_k8s_ns[@]}";i++)); do
    if [[ -n "${unique_k8s_ns[i]}" ]] ; then
      set +e; kubectl create namespace "${unique_k8s_ns[i]}" 2>/dev/null; set -e
    else
      break
    fi
  done
}

function purge_clusters {
  select choice in "ALL_CLUSTERS" "PER_CLUSTER"; do
  case "$choice" in
    ALL_CLUSTERS ) echo "$choice";
      IFS='\n' declare -g clusters=(${K8S_CLUSTERS});
      break;;
    PER_CLUSTER ) echo "$choice";
      echo "Which cluster to purge?";
      read -p "[ ${K8S_CLUSTERS} ]: " K8S_CLUSTER;
      if ! `contains_string "${K8S_CLUSTERS}" "$K8S_CLUSTER"`; then
        echo "Invalid cluster name."
        exit 3
      fi
      declare -g clusters=("$K8S_CLUSTER");
      break;;
    * ) echo "'ALL_CLUSTERS' or 'PER_CLUSTER' must be chosen.";
      exit 4;
      break;;
  esac
  done
}

function create_reg {
  # create registry container
  running="$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)"
  if [ "${running}" != 'true' ]; then
    docker run \
      -d --restart=always -p "${REG_PORT}:5000" --name "${REG_NAME}" \
      registry:2
  fi
}

function rm_reg {
  # conditionally remove registry container
  running="$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)"
  echo -e "\nPurge the local Container Registry for K8s cluster(s)?"
  select yn in "Yes" "No"; do
      case $yn in
          Yes ) echo "$yn";
            if [ "${running}" == 'true' ]; then
              docker rm -f "${REG_NAME}" >/dev/null
              echo -e "Local Container Registry - ${LIGHT_GREEN}purged${NC}."
            else
              echo -e "${LIGHT_GREEN}No local registry found.${NC}"
            fi
            break;;
          No ) echo "$yn";
            break;;
      esac
  done
}

function conn_to_kind_netw {
  CONTAINERS=$(docker network inspect kind -f "{{range .Containers}}{{.Name}} {{end}}")
  NEEDS_CONNECT="true"
  for c in $CONTAINERS; do
    if [ "$c" = "${REG_NAME}" ]; then
      NEEDS_CONNECT="false"
    fi
  done
  if [ "${NEEDS_CONNECT}" = "true" ]; then
    docker network connect kind "${REG_NAME}" 2>/dev/null || true
  fi
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
      declare -A k8s_vers_avail="$(wget -q https://registry.hub.docker.com/v1/repositories/kindest/node/tags -O - | sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' | tr '}' '\n' | awk -F: '{print $3}' | tr -d 'v')"
      if [[ -n "${k8s_vers_avail["${1#*=}"]}" ]]; then
        printf "\nIncompatible K8s node ver.\nCorrect syntax/version: ${LIGHT_GREEN}$k8s_vers_avail${NC}\n"
        exit 7
      fi
      K8S_VER="${1#*=}"
      echo $K8S_VER
      exit 11
      ;;
    --purge|-p)
      purge_clusters
      for ((i=0;i<"${#clusters[@]}";i++)); do
          "$EXEC_DIR"/kind delete cluster --name "${clusters[i]}"
      done
      printf "\n${LIGHT_GREEN}Clusters left:${NC}\n"
      "$EXEC_DIR"/kind get clusters
      rm_reg
      exit 0
      ;;
    --list-oa|-loa)
        printf "\nList of supported optional apps:\
        \n    ${LIGHT_GREEN}$SUPPORTED_OPT_APPS${NC}\n"
      exit 0
      ;;
    --create-registry|-cr)
        REG_PORT='5000'
        REG_CFG="$(<./templates/registry/kind-reg-cfg-patches.yaml)"   # Local Registry KinD patches
        create_reg
      ;;
    --helm_ver=*|-hv=*)
      if [[ "$1" != *=2 ]] && [[ "$1" != *=2.*.* ]] && [[ "$1" != *=3 ]] && [[ "$1" != *=3.*.* ]]; then
        printf "\nIncompatible Helm ver.\nSupported syntax/version: ${LIGHT_GREEN}2${NC} / ${LIGHT_GREEN}3${NC} / ${LIGHT_GREEN}2.[x].[x]${NC} / ${LIGHT_GREEN}3.[x].[x]${NC}\n"
        exit 1
      else
        if [[ "$1" == *=3.*.* ]] || [[ "$1" == *=2.*.* ]]; then HELM_VER="${1#*=}"
        elif [[ "$1" == *=3 ]]; then HELM_VER="$HELM_VER_3"
        elif [[ "$1" == *=2 ]]; then HELM_VER="$HELM_VER_2"; fi
      fi
      ;;
    --sys_wide|-sw)
      printf "\nInstalling prerequisite binaries and packages ${LIGHT_GREEN}system-wide${NC}.\n"
      SYS_WIDE=true
      EXEC_DIR='/usr/local/bin'
      ;;
    --help|-h)
      printf "\nUsage:\
        \n    ${LIGHT_GREEN}--all-labelled,-al${NC}      Set labels on all K8s nodes.\
        \n    ${LIGHT_GREEN}--all-tainted,-at${NC}       Set taints on all K8s nodes. A different label can be defined.\
        \n    ${LIGHT_GREEN}--create-registry,-cr${NC}   Create local container registry for K8s cluster(s).\
        \n    ${LIGHT_GREEN}--half-labelled,-hl${NC}     Set labels on half K8s nodes.\
        \n    ${LIGHT_GREEN}--half-tainted,-ht${NC}      Set taints on half K8s nodes. A different label can be defined.\
        \n    ${LIGHT_GREEN}--helm_ver,-hv${NC}          Set Helm version to be installed.\
        \n    ${LIGHT_GREEN}--k8s_ver,-v${NC}            Set K8s version to be deployed.\
        \n    ${LIGHT_GREEN}--list-oa,-loa${NC}          List supported optional app(s).\
        \n    ${LIGHT_GREEN}--nodes,-n${NC}              Set number of K8s nodes to be created.\
        \n    ${LIGHT_GREEN}--opt-apps,-oa${NC}          Deploy supported optional app(s).\
        \n    ${LIGHT_GREEN}--purge,-p${NC}              Purge interactively any existing cluster(s) and related resources.\
        \n    ${LIGHT_GREEN}--sys_wide,-sw${NC}          Install prerequisites system-wide.\
        \n    ${LIGHT_GREEN}--help,-h${NC}               Prints this message.\
        \nExample:\n    ${LIGHT_GREEN}bash $0 -n=2 -v=1.19.1 -hl='nodeType=devops' -ht -oa=weave-scope -cr -hv=2 -sw${NC}\n"   # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "\nError: ${LIGHT_GREEN}Invalid argument${NC}\n"
      exit 8
      ;;
  esac
  shift
done

# set up prereqs
bash "$SETUP_EXEC" "$HELM_VER" "$SYS_WIDE" "$CACHE_DIR" "$EXEC_DIR"

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

if [[ ! -z "$REG_CFG" ]]; then
  KIND_CFG="${KIND_CFG}${REG_CFG}"
fi

# Create KinD cluster
"$EXEC_DIR"/kind create cluster --config <(echo "${KIND_CFG}") --name kind-"${NO_NODES}"

if [[ ! -z "$REG_CFG" ]]; then
  "$EXEC_DIR"/kubectl apply -f templates/registry/kind-reg-configmap.yaml
  conn_to_kind_netw
fi

if [[ "$HELM_VER" == 2.*.* ]]; then
  # Adjust Tiller K8s permissions
  "$EXEC_DIR"/kubectl create serviceaccount --namespace kube-system tiller
  "$EXEC_DIR"/kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

  # Init Helm
  "$EXEC_DIR"/helm init --service-account tiller

  # check Tiller readiness
  set +e; echo 'Waiting for Tiller to become ready...'; sleep 15
  "$EXEC_DIR"/helm list >/dev/null 2>&1
  while [ $? -ne 0 ] ; do
    echo 'Another 15 sec...'
    sleep 15
    "$EXEC_DIR"/helm list >/dev/null 2>&1
  done
  set -e
fi

# Deploy default apps
create_k8s_ns
"$EXEC_DIR"/helmfile -b "$EXEC_DIR"/helm -f ./helmfiles/apps/default/helmfile.yaml apply --concurrency 1 > /dev/null

# Deploy Kubernetes Dashboard Admin ClusterRoleBinding
"$EXEC_DIR"/kubectl apply -f ./templates/k8s-dashboard-rolebinding.yaml

# Deploy conditionally optional apps
if [[ ! -z "$OPT_APPS" ]]; then
  if [[ "$OPT_APPS" == "all" ]]; then
    create_k8s_ns "$OPT_APPS"
    "$EXEC_DIR"/helmfile -b "$EXEC_DIR"/helm -f ./helmfiles/apps/optional/helmfile.yaml apply --concurrency 1 > /dev/null
  else
    for app in "$OPT_APPS"; do
      create_k8s_ns "$app"
      "$EXEC_DIR"/helmfile -b "$EXEC_DIR"/helm -f ./helmfiles/apps/optional/"$app"/helmfile.yaml apply --concurrency 1 > /dev/null
    done
  fi
fi

# Get node names
CLUSTER_WRKS=$("$EXEC_DIR"/kubectl get nodes | tail -n +2 | cut -d' ' -f1)
IFS=$'\n' CLUSTER_WRKS=(${CLUSTER_WRKS})

# Put node labels
if [[ ! -z "$COEFFICIENT_LABEL" ]]; then
  NO_NODES_LABELLED="$(bc -l <<<"${#CLUSTER_WRKS[@]} * $COEFFICIENT_LABEL" | awk '{printf("%d\n",$1 + 0.5)}')"
  for ((i=1;i<="$NO_NODES_LABELLED";i++)); do
      "$EXEC_DIR"/kubectl label node "${CLUSTER_WRKS[(i-1)]}" "$NODE_LABEL"
  done
fi

# Taint nodes with "NoExecute"
if [[ ! -z "$COEFFICIENT_TAINT" ]]; then
  NO_NODES_TAINTED="$(bc -l <<<"${#CLUSTER_WRKS[@]} * $COEFFICIENT_TAINT" | awk '{printf("%d\n",$1 + 0.5)}')"
  for ((i=1;i<="$NO_NODES_TAINTED";i++)); do
      if [[ ! -z "$NODE_LABEL" ]] && [[ -z "$NODE_TAINT_LABEL" ]] ; then
        "$EXEC_DIR"/kubectl taint node "${CLUSTER_WRKS[(i-1)]}" "$NODE_LABEL":NoExecute
      else
        "$EXEC_DIR"/kubectl taint node "${CLUSTER_WRKS[(i-1)]}" "$NODE_TAINT_LABEL":NoExecute
      fi
  done
fi
