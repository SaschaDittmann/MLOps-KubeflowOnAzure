#!/bin/bash
publicip=$(kubectl get svc -n istio-system istio-ingressgateway --no-headers | awk '{print $4}')
open "http://$publicip/"
