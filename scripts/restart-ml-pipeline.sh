#!/bin/bash
kubectl get deploy -n kubeflow -l app.kubernetes.io/name=kubeflow-pipelines -o name | \
  xargs kubectl rollout restart -n kubeflow 