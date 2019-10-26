#!/usr/bin/env bash
set -e

# Create a kINd 2-node cluster
kind create cluster --config ./kind-config-three.yaml --name kind-three
export KUBECONFIG="$(kind get kubeconfig-path --name="kind-three")"
# Deploy Tiller
kubectl create -f ../tiller.yaml
# Deploy "local-path" hostPath provisioner
kubectl create -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false", "storageclass.beta.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true", "storageclass.beta.kubernetes.io/is-default-class":"true"}}}'
# Deploy MetalLB
kubectl create -f https://raw.githubusercontent.com/google/metallb/master/manifests/metallb.yaml
kubectl create -f ../metallb-config.yaml
set +e
# Check Tiller Readiness
echo "Waiting for Tiller to become ready....."
helm list > /dev/null 2>&1
while [ $? -ne 0 ]
do
    sleep 10
    echo "Still waiting..."
    helm list > /dev/null 2>&1
done
# Init Helm Client only
helm init --client-only
export KUBECONFIG="$(kind get kubeconfig-path --name="kind-three")"
# Deploy NGINX Ingress Controller for local K8s
helm install --name ingress stable/nginx-ingress --set controller.extraArgs.enable-ssl-passthrough="",controller.hostNetwork=true,controller.kind=DaemonSet
# Put Third Node Labels
kubectl label node kind-three-worker3 nodeType=devops

