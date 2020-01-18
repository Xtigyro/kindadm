#!/usr/bin/env bash
set -e

# Create a kINd 1-node cluster
kind create cluster --config ./kind-config-one.yaml --name kind-one
# Deploy Tiller
kubectl create -f ../tiller.yaml
# Deploy MetalLB
kubectl create -f https://raw.githubusercontent.com/google/metallb/master/manifests/metallb.yaml
kubectl create -f ../metallb-config.yaml
set +e
# Check Tiller Readiness
echo "Waiting for Tiller to become ready....."
helm list > /dev/null 2>&1
while [ $? -ne 0 ]
do
    sleep 15
    echo "Still waiting..."
    helm list > /dev/null 2>&1
done
# Init Helm Client only
helm init --client-only
# Deploy NGINX Ingress Controller for local K8s
helm install --name ingress stable/nginx-ingress --set controller.extraArgs.enable-ssl-passthrough="",controller.hostNetwork=true,controller.kind=DaemonSet
# Put Node Labels
kubectl label node kind-one-control-plane nodeType=devops
# Taint the node
# kubectl taint node -l nodeType=devops nodeType=devops:NoExecute
