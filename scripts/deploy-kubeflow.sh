#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

if [ -f "./kfctl" ]; then
  echo "Using existing ktctl..."
else
  echo "Downloading kfctl..."
  downloadUrl=$(curl -s "https://api.github.com/repos/kubeflow/kfctl/releases/latest" | grep "browser_download_url.*darwin" | cut -d '"' -f 4)
  curl -L "$downloadUrl" --output kfctl.tar.gz
  tar -xvf kfctl.tar.gz
  chmod +x ./kfctl
  rm kfctl.tar.gz
fi

mkdir -p logs

export PATH=$PATH:$(pwd)

# Set KF_NAME to the name of your Kubeflow deployment. This also becomes the
# name of the directory containing your configuration.
# For example, your deployment name can be 'my-kubeflow' or 'kf-test'.
export KF_NAME='kubeflow-youtube'

# Set the path to the base directory where you want to store one or more 
# Kubeflow deployments. For example, /opt/.
# Then set the Kubeflow application directory for this deployment.
export BASE_DIR="$(pwd)/logs/kubeflow"
export KF_DIR=${BASE_DIR}/${KF_NAME}

# Set the configuration file to use, such as the file specified below:
export CONFIG_URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.2-branch/kfdef/kfctl_k8s_istio.v1.2.0.yaml"

echo "Creating Kubeflow folders..."
# Generate and deploy Kubeflow:
if [ -d "${KF_DIR}" ]; then
  rm -rf ${KF_DIR}
fi
mkdir -p ${KF_DIR}
cd ${KF_DIR}

echo "Installing Kubeflow..."
kfctl apply -V -f ${CONFIG_URI}
