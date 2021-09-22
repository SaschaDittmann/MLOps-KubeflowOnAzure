#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
ISTIO_VERSION="1.6.14"

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

if [ -f "./istioctl" ]; then
  echo "Using existing istioctl..."
else
  echo "Downloading istioctl..."
  downloadUrl="https://github.com/istio/istio/releases/download/$ISTIO_VERSION/istioctl-$ISTIO_VERSION-osx.tar.gz"
  curl -L "$downloadUrl" --output istioctl.tar.gz
  tar -xvf istioctl.tar.gz
  chmod +x ./istioctl
  rm istioctl.tar.gz
fi

./istioctl operator init

kubectl apply -f istio.aks.yaml
