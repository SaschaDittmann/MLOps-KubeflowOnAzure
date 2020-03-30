#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -s <subscriptionId> -g <resourceGroupName> -k <aksClusterName>" 1>&2; exit 1; }

declare subscriptionId=""
declare resourceGroupName="kubeflow"
declare aksClusterName="kubeflow-aks"
declare servicePrincipalName="kubeflow-spn"

if [ -f "logs/aks.json" ]; then
	echo "Loading Azure Kubernetes Service from file..."
	resourceGroupName=$(jq -r '.resourceGroup' logs/aks.json)
	aksClusterName=$(jq -r '.name' logs/aks.json)
fi

if [ -f "logs/spn.json" ]; then
	echo "Loading Service Principal from file..."
	servicePrincipalName=$(jq -r '.displayName' logs/spn.json)
fi

# Initialize parameters specified from command line
while getopts ":s:g:k:" arg; do
	case "${arg}" in
		s)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		k)
			aksClusterName=${OPTARG}
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
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$aksClusterName" ]]; then
	echo "This script will remove the Azure Kubernetes Service cluster from kubectl "
	echo "Enter a name for the AKS cluster:"
	read aksClusterName
	[[ "${aksClusterName:?}" ]]
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$aksClusterName" ]; then
	echo "Either one of subscriptionId, resourceGroupName, aksClusterName is empty"
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

#Check for existing RG
az group show --name $resourceGroupName 1> /dev/null

if [ $? != 0 ]; then
	echo "Resource group with name" $resourceGroupName "could not be found. Aborting..."
	exit 1
fi

echo "Removing resource group..."
az group delete -g "$resourceGroupName" --yes

if [ -f "logs/spn.json" ]; then
	echo "Removing Service Principal..."
	servicePrincipalObjectId=$(az ad sp list --filter "displayName eq '$servicePrincipalName'" --query "[].{objectId:objectId}" -o tsv)
	az ad sp delete --id "$servicePrincipalObjectId"
	rm -rf logs/spn.json
fi

echo "Removing kubectl config..."
kubectl config delete-cluster "$aksClusterName"
kubectl config delete-context "$aksClusterName"
kubectl config unset "users.clusterUser_$resourceGroupName""_""$aksClusterName"

echo "Removing logs folder..."
rm -rf logs
