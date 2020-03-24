#!/bin/bash
kubectl get svc -n istio-system istio-ingressgateway -o json | jq '.spec.type = "NodePort"' | kubectl apply -f -
