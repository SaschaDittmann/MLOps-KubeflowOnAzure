#!/bin/bash
kubectl get destinationrule -n kubeflow ml-pipeline -o json | jq '.spec.trafficPolicy.tls.mode = "DISABLE"' | kubectl apply -f -
kubectl get destinationrule -n kubeflow ml-pipeline-ui -o json | jq '.spec.trafficPolicy.tls.mode = "DISABLE"' | kubectl apply -f -
./restart-ml-pipeline.sh
