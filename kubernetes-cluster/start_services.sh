#!/usr/bin/env bash

set -e -o pipefail

echo "----------- 0. Fixing coreDNS clusterRole -----------"
kubectl patch clusterrole system:coredns -n kube-system --type='json' -p='[{"op": "replace", "path": "/rules/0/resources", "value":["nodes", "endpoints", "services", "pods", "namespaces"]}]'
echo "Done".

echo "----------- 1. Loading labeling service contained in the local folder -----------"
kubectl apply -f ./services/labeling_detection.yaml
echo "----------- DONE -----------"
