#!/usr/bin/env bash

set -e -o pipefail

echo "----------- 1. Deleting cluster with kops -----------"
CLUSTER_NAME="$(jq -r .kubernetes_cluster_name.value ../terraform/values.json)"
KOPS_STATE_STORE="s3://$(jq -r .kops_s3_bucket.value ../terraform/values.json)"
kops delete cluster $CLUSTER_NAME --state $KOPS_STATE_STORE --yes

echo "----------- 2. Executing terraform destroy for other resources (RDS) -----------"
cd ../terraform && terraform destroy

echo "----------- DONE -----------"