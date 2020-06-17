#!/usr/bin/env bash
set -e

LIGHT_GREEN='\033[1;32m'
NC='\033[0m' # No Color

# default Helm version
HELM_VER='2.16.9'

while [ $# -gt 0 ]; do
  case "$1" in
    --helm_ver=*|-hv=*)
      if [[ "$1" != *=* ]]; then shift; fi
      if [[ "$1" != *=2.*.* ]]; then
        printf "\nIncompatible Helm ver.\nSupported syntax/version: ${LIGHT_GREEN}2.[x].[x]${NC}\n"
        exit 1
      fi
      HELM_VER="${1#*=}"
      ;;
    --help|-h)
      printf "\nUsage:\n    ${LIGHT_GREEN}--helm_ver,-hv${NC}      Set Helm version to be deployed.\n    ${LIGHT_GREEN}--help,-h${NC}           Prints this message.\nExample:\n    ${LIGHT_GREEN}bash $0 -hv=2.16.8${NC}\n" # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "\nError: ${LIGHT_GREEN}Invalid argument${NC}\n"
      exit 2
      ;;
  esac
  shift
done

# Install req. pkgs
OS_ID=$(awk -F= '/^ID=/{print $2}' /etc/os-release)

if [ "$OS_ID" == "\"centos\"" ] || [ "$OS_ID" == "\"rhel\"" ] ; then
    yum install -y docker-ce curl
elif [ "$OS_ID" == "ubuntu" ] || [ "$OS_ID" == "debian" ] ; then
    apt update && apt install -y docker.io curl
else
    echo "Use "${0}" only on RHEL / CentOS / Ubuntu / Debian"
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
&& source <(helm completion bash)

# Install/update Helm plugins: "helm-diff", "tiller"
echo -e "\nInstalling/updating Helm plugins: \"helm-diff\" and \"tiller\"..."
helm plugin install https://github.com/rimusz/helm-tiller >/dev/null 2>&1 && \
helm plugin install https://github.com/databus23/helm-diff >/dev/null 2>&1 || \
helm plugin update diff tiller >/dev/null 2>&1
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
