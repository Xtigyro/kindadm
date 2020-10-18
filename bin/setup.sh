#!/usr/bin/env bash
set -eu

# default versions
HELM_PLUGIN_DIFF_VER='3.1.3'
HELMFILE_VER='0.130.3'
KIND_VERSION='0.9.0'
KUBECTL_VERSION='1.19.2'

# passed on vars
HELM_VER="$1"
SYS_WIDE="$2"
CACHE_DIR="$3"
EXEC_DIR="$4"

# define vars
LIGHT_GREEN='\033[1;32m'
NC='\033[0m' # No Color


# Install req. pkgs
OS_ID=$(awk -F= '/^ID=/{print $2}' /etc/os-release)

if [ "$OS_ID" == "\"centos\"" ] || [ "$OS_ID" == "\"rhel\"" ] ; then
  if ! `sudo rpm -q docker-ce curl >/dev/null 2>&1` ; then
    sudo yum install -y docker-ce curl wget
  fi
elif [ "$OS_ID" == "ubuntu" ] || [ "$OS_ID" == "debian" ] ; then
  if ! `sudo dpkg -l docker.io curl >/dev/null 2>&1` ; then
    sudo apt update && apt install -y docker.io curl wget
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
    echo -e "\n${LIGHT_GREEN}Downloading kubectl binary...${NC}" && \
    curl -L https://storage.googleapis.com/kubernetes-release/release/v"$KUBECTL_VERSION"/bin/linux/amd64/kubectl -o "$CACHE_DIR"/kubectl-"$KUBECTL_VERSION" && \
    chmod +x "$CACHE_DIR"/kubectl-"$KUBECTL_VERSION"
    yes | cp "$CACHE_DIR"/kubectl-"$KUBECTL_VERSION" "$CACHE_DIR"/kubectl
  else
    yes | cp "$CACHE_DIR"/kubectl-"$KUBECTL_VERSION" "$CACHE_DIR"/kubectl
  fi
  if [[ "$SYS_WIDE" == "true" ]] ; then
    yes | sudo cp "$CACHE_DIR"/kubectl "$EXEC_DIR/kubectl" >/dev/null 2>&1
  fi
  echo -e "\n${LIGHT_GREEN}kubectl installed:${NC}" && \
  "$EXEC_DIR/kubectl" version --client=true && \
  source <("$EXEC_DIR/kubectl" completion bash 2>/dev/null)
else
  echo -e "\n${LIGHT_GREEN}kubectl present:${NC}" && \
  "$EXEC_DIR/kubectl" version --client=true && \
  source <("$EXEC_DIR/kubectl" completion bash 2>/dev/null)
fi

# Install "helm"
if ! `"$EXEC_DIR"/helm version --client=true 2>/dev/null | grep -q "$HELM_VER"` ; then
  if ! `"$CACHE_DIR"/helm-"$HELM_VER" version --client=true 2>/dev/null | grep -q "$HELM_VER"` ; then
    echo -e "\n${LIGHT_GREEN}Downloading Helm Client binary...${NC}" && \
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
  echo -e "\n${LIGHT_GREEN}Helm installed:${NC}" && \
  "$EXEC_DIR"/helm version --client=true && \
  source <("$EXEC_DIR"/helm completion bash 2>/dev/null)
else
  echo -e "\n${LIGHT_GREEN}Helm present:${NC}" && \
  "$EXEC_DIR"/helm version --client=true
  source <("$EXEC_DIR"/helm completion bash 2>/dev/null)
fi

# Install/update Helm plugins: "helm-diff"
if ! `"$EXEC_DIR"/helm plugin list | xargs -L1 | grep -q $'diff '$HELM_PLUGIN_DIFF_VER$''` ; then
  echo -e "\nInstalling/updating Helm plugins: helm-diff..."
  if [[ "$HELM_VER" == 2.*.* ]]; then
    mkdir -p "$("$EXEC_DIR"/helm home)/plugins"
  fi
  set +e; "$EXEC_DIR"/helm plugin remove diff >/dev/null 2>&1; set -e
  "$EXEC_DIR"/helm plugin install https://github.com/databus23/helm-diff --version="$HELM_PLUGIN_DIFF_VER" >/dev/null 2>&1 || \
  "$EXEC_DIR"/helm plugin update diff >/dev/null
  echo -e "\n${LIGHT_GREEN}Helm plugins installed:${NC}"
  "$EXEC_DIR"/helm plugin list 2>/dev/null
else
  echo -e "\n${LIGHT_GREEN}Helm plugins present:${NC}" && \
  "$EXEC_DIR"/helm plugin list 2>/dev/null
fi

# Install latest "helmfile"
if ! `"$EXEC_DIR"/helmfile -v 2>/dev/null | grep -q "$HELMFILE_VER"` ; then
  if ! `"$CACHE_DIR"/helmfile -v 2>/dev/null | grep -q "$HELMFILE_VER"` ; then
    echo -e "\n${LIGHT_GREEN}Downloading Helmfile binary...${NC}" && \
    curl -L https://github.com/roboll/helmfile/releases/download/v"$HELMFILE_VER"/helmfile_linux_amd64 -o "$CACHE_DIR"/helmfile-"$HELMFILE_VER" && \
    chmod +x "$CACHE_DIR"/helmfile-"$HELMFILE_VER"
    yes | cp "$CACHE_DIR"/helmfile-"$HELMFILE_VER" "$CACHE_DIR"/helmfile
  else
    yes | cp "$CACHE_DIR"/helmfile-"$HELMFILE_VER" "$CACHE_DIR"/helmfile
  fi
  if [[ "$SYS_WIDE" == "true" ]] ; then
    yes | sudo cp "$CACHE_DIR"/helmfile "$EXEC_DIR"/helmfile >/dev/null 2>&1
  fi
  echo -e "\n${LIGHT_GREEN}Installed:${NC}" && \
  "$EXEC_DIR"/helmfile -v
else
  echo -e "\n${LIGHT_GREEN}Present:${NC}" && \
  "$EXEC_DIR"/helmfile -v
fi

# Install KinD
if ! `"$EXEC_DIR"/kind version 2>/dev/null | grep -q "$KIND_VERSION"` ; then
  if ! `"$CACHE_DIR"/kind version 2>/dev/null | grep -q "$KIND_VERSION"` ; then
    echo -e "\n${LIGHT_GREEN}Downloading KinD binary...${NC}" && \
    curl -L https://github.com/kubernetes-sigs/kind/releases/download/v"$KIND_VERSION"/kind-$(uname)-amd64 -o "$CACHE_DIR"/kind-"$KIND_VERSION" && \
    chmod +x "$CACHE_DIR"/kind-"$KIND_VERSION"
    yes | cp "$CACHE_DIR"/kind-"$KIND_VERSION" "$CACHE_DIR"/kind
  else
    yes | cp "$CACHE_DIR"/kind-"$KIND_VERSION" "$CACHE_DIR"/kind
  fi
  if [[ "$SYS_WIDE" == "true" ]] ; then
    yes | sudo cp "$CACHE_DIR"/kind "$EXEC_DIR"/kind >/dev/null 2>&1
  fi
  echo -e "\n${LIGHT_GREEN}Installed:${NC}" && \
  "$EXEC_DIR"/kind version && \
  source <("$EXEC_DIR"/kind completion bash 2>/dev/null)
  echo ""
else
  echo -e "\n${LIGHT_GREEN}Present:${NC}" && \
  "$EXEC_DIR"/kind version
  source <("$EXEC_DIR"/kind completion bash 2>/dev/null)
  echo ""
fi
