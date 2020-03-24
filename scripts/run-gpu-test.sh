#!/bin/bash
firstNode=$(kubectl get nodes -l "accelerator=nvidia" | grep -m 1 gpupool | awk '{ print $1 }')
echo "First Node: $firstNode"

numOfGPUs=$(kubectl get node $firstNode -o=json | jq -r '.status.capacity["nvidia.com/gpu"]')
echo "Number of GPU: $numOfGPUs"

echo "Running Test..."
kubectl apply -f samples-tf-mnist-demo.yaml
sleep 10

podStatus=$(kubectl get pods --selector app=samples-tf-mnist-demo | grep samples-tf-mnist-demo | awk '{ print $3 }')
echo "Job Status: $podStatus"
while [ $podStatus == "Pending" -o $podStatus == "ContainerCreating" -o $podStatus == "Running" ]
do
    sleep 15
    podStatus=$(kubectl get pods --selector app=samples-tf-mnist-demo | grep samples-tf-mnist-demo | awk '{ print $3 }')
    echo "Job Status: $podStatus"
done

podName=$(kubectl get pods --selector app=samples-tf-mnist-demo | grep samples-tf-mnist-demo | awk '{ print $1 }')
kubectl logs "$podName"

kubectl delete jobs samples-tf-mnist-demo
