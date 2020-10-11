#!/usr/bin/env bash
set -e

# default versions
HELM_VER='2.16.12'
HELM_PLUGIN_DIFF_VER='3.1.3'
HELM_PLUGIN_TILLER_VER='0.9.3'
HELMFILE_VER='0.130.1'
KIND_VERSION='0.9.0'
KUBECTL_VERSION='1.19.2'
CACHE_DIR="$(dirname "${BASH_SOURCE[0]}")/.cache"
EXEC_DIR="$CACHE_DIR"

LIGHT_GREEN='\033[1;32m'
NC='\033[0m' # No Color


while [ $# -gt 0 ]; do
  case "$1" in
    --helm_ver=*|-hv=*)
      if [[ "$1" != *=2.*.* ]]; then
        printf "\nIncompatible Helm ver.\nSupported syntax/version: ${LIGHT_GREEN}2.[x].[x]${NC}\n"
        exit 1
      fi
      HELM_VER="${1#*=}"
      ;;
    --sys_wide|-sw)
      printf "\nInstalling prerequisite binaries and packages ${LIGHT_GREEN}system-wide${NC}.\n"
      SYS_WIDE=true
      EXEC_DIR='/usr/local/bin'
      ;;
    --help|-h)
      printf "\nUsage:\
        \n    ${LIGHT_GREEN}--helm_ver,-hv${NC}      Set Helm version to be deployed.\
        \n    ${LIGHT_GREEN}--sys_wide,-sw${NC}      Install prerequisites system-wide.\
        \n    ${LIGHT_GREEN}--help,-h${NC}           Prints this message.\
        \nExample:\n    ${LIGHT_GREEN}bash $0 -hv=2.16.12 -sw${NC}\n"   # Flag argument
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
  if ! `sudo rpm -q docker-ce curl >/dev/null 2>&1` ; then
    sudo yum install -y docker-ce curl
  fi
elif [ "$OS_ID" == "ubuntu" ] || [ "$OS_ID" == "debian" ] ; then
  if ! `sudo dpkg -l docker.io curl >/dev/null 2>&1` ; then
    sudo apt update && apt install -y docker.io curl
  fi
else
    echo "Use "${0}" only on RHEL / CentOS / Ubuntu / Debian"
    exit 3
fi

# Unmask and start Docker service
sudo systemctl is-active --quiet docker || \
sudo systemctl unmask docker && \
sudo systemctl start docker

# Create cache dir
mkdir -p "$CACHE_DIR"

# Install latest "kubectl"
if ! `"$EXEC_DIR"/kubectl version --client=true 2>/dev/null | grep -q "$KUBECTL_VERSION"` ; then
  if ! `"$CACHE_DIR"/kubectl version --client=true 2>/dev/null | grep -q "$KUBECTL_VERSION"` ; then
    echo -e "\nDownloading kubectl binary..." && \
    curl -L https://storage.googleapis.com/kubernetes-release/release/v"$KUBECTL_VERSION"/bin/linux/amd64/kubectl -o "$CACHE_DIR"/kubectl && \
    chmod +x "$CACHE_DIR"/kubectl
  fi
  if [[ "$SYS_WIDE" == "true" ]] ; then
    yes | sudo cp "$CACHE_DIR"/kubectl "$EXEC_DIR/kubectl" >/dev/null 2>&1
  fi
  echo -e "\nkubectl installed:" && \
  "$EXEC_DIR/kubectl" version --client=true && \
  source <("$EXEC_DIR/kubectl" completion bash 2>/dev/null)
else
  echo -e "\nkubectl present:" && \
  "$EXEC_DIR/kubectl" version --client=true && \
  source <("$EXEC_DIR/kubectl" completion bash 2>/dev/null)
fi

# Install "helm"
if ! `"$EXEC_DIR"/helm version --client=true 2>/dev/null | grep -q "$HELM_VER"` ; then
  if ! `"$CACHE_DIR"/helm-"$HELM_VER" version --client=true 2>/dev/null | grep -q "$HELM_VER"` ; then
    echo -e "\nDownloading Helm Client binary..." && \
    curl -L https://get.helm.sh/helm-v"$HELM_VER"-linux-amd64.tar.gz -o "$CACHE_DIR"/helm-v"$HELM_VER"-linux-amd64.tar.gz && \
    tar xf "$CACHE_DIR"/helm-v"$HELM_VER"-linux-amd64.tar.gz -C "$CACHE_DIR" && \
    chmod +x "$CACHE_DIR"/linux-amd64/helm && \
    yes | cp "$CACHE_DIR"/linux-amd64/helm "$CACHE_DIR"/helm-"$HELM_VER" && \
    yes | mv "$CACHE_DIR"/linux-amd64/helm "$CACHE_DIR"/helm
  else
    yes | cp "$CACHE_DIR"/helm-"$HELM_VER" "$CACHE_DIR"/helm
  fi
  if [[ "$SYS_WIDE" == "true" ]] ; then
    yes | sudo cp "$CACHE_DIR"/helm "$EXEC_DIR"/helm >/dev/null 2>&1
  fi
  sudo rm -rf "$CACHE_DIR"/linux-amd64 "$CACHE_DIR"/helm-v"$HELM_VER"-linux-amd64.tar.gz && \
  echo -e "\nHelm installed:" && \
  "$EXEC_DIR"/helm version --client=true && \
  source <("$EXEC_DIR"/helm completion bash 2>/dev/null)
else
  echo -e "\nHelm present:" && \
  "$EXEC_DIR"/helm version --client=true
fi

# Install/update Helm plugins: "helm-diff", "tiller"
if ! `"$EXEC_DIR"/helm plugin list | xargs -L1 | grep -Eq $'tiller '"$HELM_PLUGIN_TILLER_VER"$'|diff '$HELM_PLUGIN_DIFF_VER$''` ; then
  echo -e "\nInstalling/updating Helm plugins: \"helm-diff\" and \"tiller\"..."
  mkdir -p "$("$EXEC_DIR"/helm home)/plugins"
  set +e; "$EXEC_DIR"/helm plugin remove tiller diff >/dev/null 2>&1; set -e
  "$EXEC_DIR"/helm plugin install https://github.com/rimusz/helm-tiller --version="$HELM_PLUGIN_TILLER_VER" >/dev/null 2>&1 && \
  "$EXEC_DIR"/helm plugin install https://github.com/databus23/helm-diff --version="$HELM_PLUGIN_DIFF_VER" >/dev/null 2>&1 || \
  "$EXEC_DIR"/helm plugin update diff tiller >/dev/null
  echo -e "\nHelm plugins installed:"
  "$EXEC_DIR"/helm plugin list 2>/dev/null
else
  echo -e "\nHelm plugins present:" && \
  "$EXEC_DIR"/helm plugin list 2>/dev/null
fi

# Install latest "helmfile"
if ! `"$EXEC_DIR"/helmfile -v 2>/dev/null | grep -q "$HELMFILE_VER"` ; then
  if ! `"$CACHE_DIR"/helmfile -v 2>/dev/null | grep -q "$HELMFILE_VER"` ; then
    echo -e "\nDownloading Helmfile binary..." && \
    curl -L https://github.com/roboll/helmfile/releases/download/v"$HELMFILE_VER"/helmfile_linux_amd64 -o "$CACHE_DIR"/helmfile && \
    chmod +x "$CACHE_DIR"/helmfile
  fi
  if [[ "$SYS_WIDE" == "true" ]] ; then
    yes | sudo cp "$CACHE_DIR"/helmfile "$EXEC_DIR"/helmfile >/dev/null 2>&1
  fi
  echo -e "\nInstalled:" && \
  "$EXEC_DIR"/helmfile -v
else
  echo -e "\nPresent:" && \
  "$EXEC_DIR"/helmfile -v
fi

# Install kINd
if ! `"$EXEC_DIR"/kind version 2>/dev/null | grep -q "$KIND_VERSION"` ; then
  if ! `"$CACHE_DIR"/kind version 2>/dev/null | grep -q "$KIND_VERSION"` ; then
    echo -e "\nDownloading kINd binary..." && \
    curl -L https://github.com/kubernetes-sigs/kind/releases/download/v"$KIND_VERSION"/kind-$(uname)-amd64 -o "$CACHE_DIR"/kind && \
    chmod +x "$CACHE_DIR"/kind
  fi
  if [[ "$SYS_WIDE" == "true" ]] ; then
    yes | sudo cp "$CACHE_DIR"/kind "$EXEC_DIR"/kind >/dev/null 2>&1
  fi
  echo -e "\nInstalled:" && \
  "$EXEC_DIR"/kind version && \
  source <("$EXEC_DIR"/kind completion bash 2>/dev/null)
else
  echo -e "\nPresent:" && \
  "$EXEC_DIR"/kind version
fi
