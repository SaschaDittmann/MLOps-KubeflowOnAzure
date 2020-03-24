#!/bin/bash
echo "Running Test..."
kubectl apply -f test-virtual-node.yaml
sleep 10

podStatus=$(kubectl get pods --selector app=aci-helloworld | grep aci-helloworld | awk '{ print $3 }')
echo "Job Status: $podStatus"
while [ $podStatus == "Waiting" -o $podStatus == "ContainerCreating" -o $podStatus == "Creating" ]
do
    sleep 15
    podStatus=$(kubectl get pods --selector app=aci-helloworld | grep aci-helloworld | awk '{ print $3 }')
    echo "Job Status: $podStatus"
done

echo "Retrieving Log..."
podName=$(kubectl get pods --selector app=aci-helloworld | grep aci-helloworld | awk '{ print $1 }')
kubectl logs "$podName"

echo "Querying Service..."
publicId=$(kubectl get service aci-helloworld | grep -m 1 aci-helloworld | awk '{ print $4 }')
curl -L $publicId

kubectl delete service aci-helloworld
kubectl delete deployment aci-helloworld
