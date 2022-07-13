#!/usr/bin/env bash

set -e -o pipefail

echo "----------- 1. Go to terraform folder -----------"
cd ../terraform

echo "----------- 2. Get kubernetes_cluster_name and kops_s3_bucket values with jq -----------"
export CLUSTER_NAME="$(jq -r .kubernetes_cluster_name.value values.json)"
export KOPS_STATE_STORE="s3://$(jq -r .kops_s3_bucket.value values.json)"
echo $CLUSTER_NAME
echo $KOPS_STATE_STORE

echo "----------- 3. Rolling update cluster -----------"
# Rolling update often needed to make sure all nodes join the cluster and the configuration is updated
# It is really wonky, sometimes it just does not work and I have to restart it multiple times.
kops rolling-update cluster --cloudonly --name $CLUSTER_NAME --state $KOPS_STATE_STORE --force --yes
# Validation does not end because some default stuff is not installed. It should be an issue with t2.micro instances.
# kops validate cluster --state $KOPS_STATE_STORE --wait 10m

echo "----------- DONE -----------"
echo "If some nodes do not show up after 15 minutes, do another rolling update."