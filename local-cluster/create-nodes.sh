#!/usr/bin/env bash
set -e

NO_NODES="${1}"

case "${NO_NODES}" in
  "1")
  CLUSTER_WRKS=(kind-1-control-plane)
  ;;
  "2")
  CLUSTER_WRKS=(kind-2-worker2)
  ;;
  "3")
  CLUSTER_WRKS=(kind-3-worker2 kind-3-worker3)
  ;;
  *)
  echo -e "\e[32m\n\e[1mPass the number of the desired nodes - 1|2|3.\e[00m"
  exit 11
  ;;
esac

# Create kINd cluster
kind create cluster --config ./kind-config-"${NO_NODES}".yaml --name kind-"${NO_NODES}"
# Deploy MetalLB
kubectl create -f https://raw.githubusercontent.com/google/metallb/master/manifests/metallb.yaml
kubectl create -f ../metallb-config.yaml
# Deploy desired svc-s
helmfile -f ../helmfile.yaml apply > /dev/null
# Put Node Labels
for ((i=0;i<=${#CLUSTER_WRKS[@]};i++));
  do
    if [ -n "${CLUSTER_WRKS[i]}" ] ; then
      kubectl label node "${CLUSTER_WRKS[i]}" nodeType=devops
    else
      break
    fi
  done
# Taint the node
# kubectl taint node -l nodeType=devops nodeType=devops:NoExecute
