#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -s <subscriptionId> -g <resourceGroupName> -w <workspaceName> -r <containerRegistryName>" 1>&2; exit 1; }

declare subscriptionId="d2494347-ee90-4f61-8203-dcebbdb6678a"
declare resourceGroupName="kubeflow"
declare containerRegistryName=""
if [ -f "logs/acr.json" ]; then
	resourceGroupName=$(jq -r '.resourceGroup' logs/acr.json)
	containerRegistryName=$(jq -r '.name' logs/acr.json)
fi
declare workspaceName="kubeflow-mlwrksp"

# Initialize parameters specified from command line
while getopts ":s:g:w:r:h" arg; do
	case "${arg}" in
		s)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		w)
			workspaceName=${OPTARG}
			;;
		r)
			containerRegistryName=${OPTARG}
			;;
		h)
			usage
			;;
		?) 
			echo "Unknown option ${arg}"
			;;
		esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
	echo "Your subscription ID can be looked up with the CLI using: az account show --out json "
	echo "Enter your subscription ID:"
	read subscriptionId
	[[ "${subscriptionId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
	echo "This script will look for an existing resource group "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name:"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$workspaceName" ]]; then
	echo "This script will look for an existing Azure Machine Learning Workspace "
	echo "You can list all workspaces with the CLI using: az ml workspace list "
	echo "Enter a resource group name"
	read workspaceName
fi

if [[ -z "$containerRegistryName" ]]; then
	echo "This script use the created Azure Container Registry "
	echo "This service is used to store private docker images "
	echo "Enter a name for the ACR:"
	read containerRegistryName
	[[ "${containerRegistryName:?}" ]]
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$workspaceName" ] || [ -z "$containerRegistryName" ]; then
	echo "Either one of subscriptionId, resourceGroupName, workspaceName, containerRegistryName is empty"
	usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

set +e

echo "Checking Azure CLI Extensions..."
if [ -z "$(az extension list -o tsv | grep azure-cli-ml)" ]; then
	echo "This scripts required the Azure CLI extention for machine learning."
    echo "It can me installed by using this CLI command: az extension add -n azure-cli-ml" 
	exit 0
fi

echo "Retrieving Azure Container Registry ID..."
acrResourceId=$(az acr show -g "$resourceGroupName" -n "$containerRegistryName" | jq -r .id)

if [ -f "logs/aml-workspace.json" ]; then
    echo "Loading Azure Machine Learning workspace from file..."
	amlResult=$(cat logs/aml-workspace.json)
else
	echo "Creating a Azure Machine Learning workspace..."
	amlResult=$(az ml workspace create -g "$resourceGroupName" -w "$workspaceName" --container-registry "$acrResourceId" --exist-ok)
	if [ $? != 0 ];
	then
		echo "Creating the Azure Machine Learning workspace failed. Aborting..."
		exit 1
	fi
	echo $amlResult | tee logs/aml-workspace.json > /dev/null
fi

echo "Azure Machine Learning has been successfully deployed"
