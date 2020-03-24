#!/bin/bash
kubectl get svc -n istio-system istio-ingressgateway -o json | jq '.spec.type = "LoadBalancer"' | kubectl apply -f -
