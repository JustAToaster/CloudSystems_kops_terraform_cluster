#!/usr/bin/env bash

set -e -o pipefail

echo "----------- 0. Attach all necessary permissions to kops group -----------"
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess --group-name kops

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
export SAGEMAKER_INSTANCE_NAME="$(jq -r .sagemaker_instance_name.value values.json)"
echo $CLUSTER_NAME
echo $KOPS_STATE_STORE
echo $SAGEMAKER_INSTANCE_NAME

echo "----------- 6. Stopping SageMaker notebook instance (will start only on demand) -----------"
aws sagemaker stop-notebook-instance --notebook-instance-name $SAGEMAKER_INSTANCE_NAME
echo "Done."

echo "----------- 7. Generating cluster.yaml and service YAMLs from templates and terraform values -----------"
kops toolbox template --name $CLUSTER_NAME --state $KOPS_STATE_STORE --values values.json --template ../kubernetes-cluster/cluster-template.yaml --format-yaml > cluster.yaml
kops toolbox template --name $CLUSTER_NAME --state $KOPS_STATE_STORE --values values.json --template ../kubernetes-cluster/services_templates/helmet_detector_template.yaml --format-yaml > ../kubernetes-cluster/services/helmet_detector.yaml
kops toolbox template --name $CLUSTER_NAME --state $KOPS_STATE_STORE --values values.json --template ../kubernetes-cluster/services_templates/labeling_detection_template.yaml --format-yaml > ../kubernetes-cluster/services/helmet_detector.yaml
echo "Done."

echo "----------- 8. Creating cluster with cluster.yaml configuration -----------"
kops replace -f cluster.yaml --name $CLUSTER_NAME --state $KOPS_STATE_STORE  --force
echo "Done."

echo "----------- 9. Create secret with local rsa key -----------"
kops create secret --name $CLUSTER_NAME --state $KOPS_STATE_STORE sshpublickey admin -i ~/.ssh/id_rsa.pub
echo "Done."

echo "----------- 10. Updating cluster -----------"
#export KOPS_RUN_TOO_NEW_VERSION=1
kops update cluster --name $CLUSTER_NAME --state $KOPS_STATE_STORE --yes
kops export kubecfg --name $CLUSTER_NAME --state $KOPS_STATE_STORE --admin=8670h0m0s
# Attach EC2FullAccess to avoid authorization issues inside the instances
aws iam attach-role-policy --role-name nodes.$CLUSTER_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy --role-name masters.$CLUSTER_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
# Attach S3FullAccess to nodes, so that they can send training data to S3 for the SageMaker instance to use
aws iam attach-role-policy --role-name nodes.$CLUSTER_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

echo "Done."

#echo "----------- 11. Rolling update cluster -----------"
# Rolling update often needed to make sure all nodes join the cluster and the configuration is updated
# It is really wonky, sometimes it just does not work and I have to restart it multiple times.
#kops rolling-update cluster --cloudonly --name $CLUSTER_NAME --state $KOPS_STATE_STORE --force --yes
# Validation does not end because some default stuff is not installed. It should be an issue with t2.micro instances.
# kops validate cluster --state $KOPS_STATE_STORE --wait 10m

echo "----------- DONE -----------"
echo "The cluster will be ready in a few minutes. Hopefully..."
echo "If some nodes do not show up after 10 minutes, do a rolling update with ./rolling_update_cluster.sh"

# Create the tables used by the services for logging
echo "----------- Connecting to the RDS instance to create tables and triggers -----------"
PGPASSWORD=$(terraform output -raw db_password) psql -h $(terraform output -raw rds_address) -P $(terraform output -raw rds_port) -U $(terraform output -raw db_username) -f "../sql/init_db.sql"
echo "Done."
# You can connect to the EC2 instances with:
# ssh ubuntu@ec2-[public_ip].compute-1.amazonaws.com