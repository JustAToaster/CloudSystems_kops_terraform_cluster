#!/usr/bin/env bash

set -e -o pipefail

echo "----------- 1. Executing terraform init -----------"
cd ../terraform && terraform init

echo "----------- 2. Executing terraform plan -----------"
terraform plan

read -p "Press y/Y to create the infrastructure with this configuration. " -n 1 -r
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

# Create the tables used by the services for logging
echo "----------- Connecting to the RDS instance to create tables and triggers -----------"
PGPASSWORD=$(terraform output -raw db_password) psql --host=$(terraform output -raw rds_address) --port=$(terraform output -raw rds_port) --username=$(terraform output -raw db_username) --dbname=postgres -f "../sql/init_db.sql"
echo "Done."
# You can connect to the EC2 instances with:
# ssh ubuntu@ec2-[public_ip].compute-1.amazonaws.com