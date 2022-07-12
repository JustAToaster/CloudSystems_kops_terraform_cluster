#!/usr/bin/env bash

set -e -o pipefail

echo "----------- 1. Executing terraform init -----------"
cd ../terraform && terraform init

echo "----------- 2. Executing terraform plan -----------"
terraform plan

read -p "Press y/Y to create the cluster with this configuration. " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Exiting..."
    exit 1
fi
echo
echo "Cluster creation starting."

echo "----------- 3. Executing terraform apply -----------"
terraform apply

echo "----------- 4. Getting terraform output as json -----------"
terraform output -json > values.json
echo "Done."
# yq eval -P values.json > values.yaml

echo "----------- 5. Get kubernetes_cluster_name and kops_s3_bucket values with jq -----------"
export CLUSTER_NAME="$(jq -r .kubernetes_cluster_name.value values.json)"
export KOPS_STATE_STORE="s3://$(jq -r .kops_s3_bucket.value values.json)"
echo $CLUSTER_NAME
echo $KOPS_STATE_STORE

echo "----------- 6. Generating cluster.yaml and service YAMLs from template and terraform values -----------"
kops toolbox template --name $CLUSTER_NAME --values values.json --template ../kubernetes-cluster/cluster-template.yaml --format-yaml > cluster.yaml
kops toolbox template --values values.json --template ../kubernetes-cluster/services_templates/helmet_detector_template.yaml --format-yaml > ../kubernetes-cluster/services/helmet_detector.yaml
echo "Done."

echo "----------- 7. Creating cluster with cluster.yaml configuration -----------"
kops replace -f cluster.yaml --state $KOPS_STATE_STORE --name $CLUSTER_NAME --force
echo "Done."

echo "----------- 8. Create secret with local rsa key -----------"
kops create secret --name $CLUSTER_NAME --state $KOPS_STATE_STORE sshpublickey admin -i ~/.ssh/id_rsa.pub
echo "Done."

echo "----------- 9. Updating cluster -----------"
#export KOPS_RUN_TOO_NEW_VERSION=1
kops update cluster --state $KOPS_STATE_STORE --name $CLUSTER_NAME --yes
kops export kubecfg --name $CLUSTER_NAME --state $KOPS_STATE_STORE --admin=8670h0m0s
echo "Done."

echo "----------- 10. Rolling update and validating cluster -----------"
# Rolling update often needed to make sure all nodes join the cluster and the configuration is updated
# It is really wonky, sometimes it just does not work and I have to restart it multiple times.
kops rolling-update cluster --cloudonly --state $KOPS_STATE_STORE --force --yes
# Validation does not end because some default stuff is not installed. It should be an issue with t2.micro instances.
# kops validate cluster --state $KOPS_STATE_STORE --wait 10m

echo "----------- DONE -----------"
echo "If some nodes do not show up after 15 minutes, do another rolling update."

# Connect to RDS instance to create the tables
echo "----------- Connecting to the RDS instance to create tables -----------"
mysql -h $(terraform output -raw rds_address) -P $(terraform output -raw rds_port) -u $(terraform output -raw db_username) -p$(terraform output -raw db_password) -e "CREATE DATABASE yolov5_predictions;CREATE TABLE yolov5_predictions.requests (Address varchar(255),ImageName varchar(255),JsonPredictions varchar(5000));"

# You can connect to the EC2 instances with:
# ssh ubuntu@ec2-[public_ip].compute-1.amazonaws.com