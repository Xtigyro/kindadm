#!/usr/bin/env bash
set -e

# Install req. pkgs
OS_ID=$(awk -F= '/^ID=/{print $2}' /etc/os-release)

if [ "$OS_ID" == "\"centos\"" ] || [ "$OS_ID" == "\"rhel\"" ] ; then
    yum install -y docker-ce
elif [ "$OS_ID" == "ubuntu" ] ; then
    apt update && apt install -y docker.io
else
    echo "Use "${0}" only on RHEL / CentOS / Ubuntu "
    exit 1
fi

# Start Docker
systemctl start docker

# Install "kubectl"
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl \
&& chmod +x ./kubectl \
&& sudo mv ./kubectl /usr/local/bin/kubectl

# Install "helm"
HELM_VERSION=v2.14.3
curl -LO https://get.helm.sh/helm-"$HELM_VERSION"-linux-amd64.tar.gz \
&& tar xf helm-"$HELM_VERSION"-linux-amd64.tar.gz \
&& mv ./linux-amd64/helm ./linux-amd64/tiller /usr/local/bin \
&& rm -rf ./linux-amd64 helm-"$HELM_VERSION"-linux-amd64.tar.gz

# Install kINd
KIND_VERSION=v0.5.1 \
&& curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/"$KIND_VERSION"/kind-$(uname)-amd64 \
&& chmod +x ./kind \
&& mv ./kind /usr/local/bin/kind
