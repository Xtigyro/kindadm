#!/usr/bin/env bash
set -e

# default Helm version
HELM_VER='3.2.3'

while [ $# -gt 0 ]; do
  case "$1" in
    --helm_ver*|-hv*)
      if [[ "$1" != *=* ]]; then shift; fi
      if [[ "$1" != *3.*.* ]]; then
        printf "\e[32m\n\e[1mIncompatible Helm ver.\nSupported syntax/version: 3.x.x\e[00m\n"
        exit 1
      fi
      HELM_VER="${1#*=}"
      ;;
    --help|-h)
      printf "\nUsage:\e[32m\e[1m\n    --helm_ver,-hv      Set Helm version to be deployed.\n    --help,-h           Prints this message.\n\e[00mExample:\e[32m\e[1m\n    bash $0 -hv=3.2.3\e[00m\n" # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "\e[32m\n\e[1mError: Invalid argument\e[00m\n"
      exit 2
      ;;
  esac
  shift
done

# Install req. pkgs
OS_ID=$(awk -F= '/^ID=/{print $2}' /etc/os-release)

if [ "$OS_ID" == "\"centos\"" ] || [ "$OS_ID" == "\"rhel\"" ] ; then
    yum install -y docker-ce curl
elif [ "$OS_ID" == "ubuntu" ] ; then
    apt update && apt install -y docker.io curl
else
    echo "Use "${0}" only on RHEL / CentOS / Ubuntu "
    exit 3
fi

# Unmask and start Docker service
sudo systemctl unmask docker \
&& sudo systemctl start docker

# Install latest "kubectl"
KUBECTL_VERSION="$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"
echo -e "\nDownloading kubectl binary..." \
&& curl -LO https://storage.googleapis.com/kubernetes-release/release/"$KUBECTL_VERSION"/bin/linux/amd64/kubectl \
&& chmod +x ./kubectl \
&& yes | sudo mv ./kubectl /usr/local/bin/kubectl \
&& echo -e "\nkubectl version:" \
&& kubectl version --client=true 2>/dev/null \
&& source <(kubectl completion bash 2>/dev/null)

# Install "helm"
echo -e "\nDownloading Helm Client binary..." \
&& curl -LO https://get.helm.sh/helm-v"$HELM_VER"-linux-amd64.tar.gz \
&& tar xf helm-v"$HELM_VER"-linux-amd64.tar.gz \
&& yes | mv ./linux-amd64/helm /usr/local/bin \
&& rm -rf ./linux-amd64 helm-v"$HELM_VER"-linux-amd64.tar.gz \
&& echo -e "\nhelm version:" \
&& helm version 2>/dev/null \
&& source <(helm completion bash 2>/dev/null)

# Install/update Helm plugins: "helm-diff"
echo -e "\nInstalling/updating Helm plugins: helm-diff..."
helm plugin install https://github.com/databus23/helm-diff >/dev/null 2>&1 \
|| helm plugin update diff >/dev/null 2>&1
echo -e "\nInstalled Helm plugins:"
helm plugin list 2>/dev/null

# Install latest "helmfile"
echo -e "\nDownloading Helmfile binary..." \
&& curl -LO https://github.com/roboll/helmfile/releases/latest/download/helmfile_linux_amd64 \
&& chmod +x ./helmfile_linux_amd64 \
&& yes | mv ./helmfile_linux_amd64 /usr/local/bin/helmfile \
&& helmfile -v 2>/dev/null

# Install kINd
KIND_VERSION=v0.8.1 \
&& echo -e "\nDownloading kINd binary..." \
&& curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/"$KIND_VERSION"/kind-$(uname)-amd64 \
&& chmod +x ./kind \
&& yes | mv ./kind /usr/local/bin/kind \
&& echo -e "\nkINd version:" \
&& kind version \
&& source <(kind completion bash)
