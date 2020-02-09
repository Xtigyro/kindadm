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

# Unmask and start Docker service
sudo systemctl unmask docker \
&& sudo systemctl start docker

# Install "kubectl"
echo -e "\nDownloading kubectl binary..." \
&& curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl \
&& chmod +x ./kubectl \
&& sudo mv ./kubectl /usr/local/bin/kubectl \
&& echo -e "\nkubectl version:" \
&& kubectl version 2>/dev/null \
&& source <(kubectl completion bash)

# Install "helm"
HELM_VERSION=v2.16.1 \
&& echo -e "\nDownloading Helm Client binary..." \
&& curl -LO https://get.helm.sh/helm-"$HELM_VERSION"-linux-amd64.tar.gz \
&& tar xf helm-"$HELM_VERSION"-linux-amd64.tar.gz \
&& mv ./linux-amd64/helm ./linux-amd64/tiller /usr/local/bin \
&& rm -rf ./linux-amd64 helm-"$HELM_VERSION"-linux-amd64.tar.gz \
&& echo -e "\nhelm version:" \
&& helm version 2>/dev/null \
&& source <(helm completion bash)

# Install Helm plugins: "helm-tiller" and "helm-diff"
echo -e "\nInstalling Helm plugins: helm-tiller and helm-diff..." \
&& helm plugin install https://github.com/rimusz/helm-tiller \
&& helm plugin install https://github.com/databus23/helm-diff

# Install "helmfile"
HELMFILE_VERSION=v0.99.0 \
&& echo -e "\nDownloading Helmfile binary..." \
&& curl -LO https://github.com/roboll/helmfile/releases/download/"$HELMFILE_VERSION"/helmfile_linux_amd64 \
&& chmod +x ./helmfile_linux_amd64 \
&& mv ./helmfile_linux_amd64 /usr/local/bin/helmfile \
&& helmfile -v 2>/dev/null

# Install kINd
KIND_VERSION=v0.7.0 \
&& echo -e "\nDownloading kINd binary..." \
&& curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/"$KIND_VERSION"/kind-$(uname)-amd64 \
&& chmod +x ./kind \
&& mv ./kind /usr/local/bin/kind \
&& echo -e "\nkINd version:" \
&& kind version \
&& source <(kind completion bash)
