#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -s <subscriptionId> -g <resourceGroupName> -k <aksClusterName> -p <nodepoolName> -v <kubernetesVersion> -n <vnetName>" 1>&2; exit 1; }

declare subscriptionId=""
declare resourceGroupName="kubeflow"
declare vnetName="kubeflow-vnet"
declare aksClusterName="kubeflow-aks"
declare kubernetesVersion="1.15.10"
declare nodepoolName="cpupool1"
declare vmSize="Standard_DS13_v2"

if [ -f "logs/aks.json" ]; then
	echo "Loading Azure Kubernetes Service from file..."
	resourceGroupName=$(jq -r '.resourceGroup' logs/aks.json)
	aksClusterName=$(jq -r '.name' logs/aks.json)
	kubernetesVersion=$(jq -r '.kubernetesVersion' logs/aks.json)
fi

# Initialize parameters specified from command line
while getopts ":s:g:k:v:n:p:h" arg; do
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
		v)
			kubernetesVersion=${OPTARG}
			;;
		n)
			vnetName=${OPTARG}
			;;
		p)
			nodepoolName=${OPTARG}
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
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$aksClusterName" ]]; then
	echo "This script will create an Azure Kubernetes Service node pool "
	echo "Enter a name for the AKS cluster:"
	read aksClusterName
	[[ "${aksClusterName:?}" ]]
fi

if [[ -z "$kubernetesVersion" ]]; then
	echo "Which version of Kubernetes should be used for the AKS node pool "
	echo "Enter a Kubernetes version:"
	read kubernetesVersion
	[[ "${kubernetesVersion:?}" ]]
fi

if [[ -z "$nodepoolName" ]]; then
	echo "This script will create an Azure Kubernetes Service node pool "
	echo "Enter a name for the node pool:"
	read nodepoolName
	[[ "${nodepoolName:?}" ]]
fi

if [[ -z "$vnetName" ]]; then
	echo "This script will use the existing Virtual Network for the AKS "
	echo "Enter a name for the Virtual Network:"
	read vnetName
	[[ "${vnetName:?}" ]]
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$aksClusterName" ] || [ -z "$kubernetesVersion" ] || [ -z "$nodepoolName" ]; then
	echo "Either one of subscriptionId, resourceGroupName, aksClusterName, kubernetesVersion, nodepoolName is empty"
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

if [ -f "logs/vnet-subnet-default.json" ]; then
    echo "Loading Virtual Network Subnet from file..."
	subnetId=$(jq -r '.newVNet.subnets[0] | select(.name=="default") | .id' logs/vnet-subnet-default.json)
else
	echo "Loading Virtual Network Subnet from the Azure API..."
	subnetId=$(az network vnet subnet show -g "$resourceGroupName" --vnet-name "$vnetName" --name "default" | jq -r .id)
fi

echo "Querying existing Node Pools..."
existingNodePool=$(az aks nodepool list -g "$resourceGroupName" --cluster-name "$aksClusterName" -o tsv | grep "$nodepoolName")
if [[ -z "$existingNodePool" ]]; then
	echo "Adding Node Pool..."
	$nodePoolResult=$(az aks nodepool add -g "$resourceGroupName" --cluster-name "$aksClusterName" \
		-s "$vmSize" -c 1 -k "$kubernetesVersion" \
		--enable-cluster-autoscaler --min-count 1 --max-count 10 \
		-n "$nodepoolName" --vnet-subnet-id "$subnetId")
	if [ $?  == 0 ]; then
		echo "AKS Node Pool has been successfully deployed"
	fi
	echo $nodePoolResult | tee "logs/aks-$nodepoolName.json"
else
	echo "Node Pool $nodepoolName does already exist."
fi
