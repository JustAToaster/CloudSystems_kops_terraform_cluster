#!/usr/bin/env bash

set -e -o pipefail

echo "----------- Starting validation -----------"
CLUSTER_NAME="$(jq -r .kubernetes_cluster_name.value ../terraform/values.json)"
KOPS_STATE_STORE="s3://$(jq -r .kops_s3_bucket.value ../terraform/values.json)"
kops validate cluster --state $KOPS_STATE_STORE --wait 10m
echo "----------- DONE -----------"