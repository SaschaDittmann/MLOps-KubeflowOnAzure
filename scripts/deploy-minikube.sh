#!/bin/bash
declare kubernetesVersion="1.17.13"

minikube start --cpus 6 --memory 12288 --disk-size=120g \
	--extra-config=apiserver.service-account-issuer=api \
	--extra-config=apiserver.service-account-signing-key-file=/var/lib/minikube/certs/apiserver.key \
	--extra-config=apiserver.service-account-api-audiences=api \
	--kubernetes-version="$kubernetesVersion" \
	--driver='parallels'
