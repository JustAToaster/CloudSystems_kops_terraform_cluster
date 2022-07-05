#!/usr/bin/env bash

set -e -o pipefail

echo "----------- 1. Loading services from online manifests -----------"
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.2.1/deploy/static/provider/cloud/deploy.yaml
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.5.0/aio/deploy/recommended.yaml

echo "----------- 2. Loading services contained in the local folder -----------"
kubectl apply -f ./services