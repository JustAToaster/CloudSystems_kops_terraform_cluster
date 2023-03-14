#!/usr/bin/env bash

set -e -o pipefail

echo "----------- 1. Setting environment variables from Terraform -----------"
cd ../terraform
export DB_HOSTNAME=$(terraform output -raw rds_address)
export DB_USERNAME=$(terraform output -raw db_username)
export DB_PASSWORD=$(terraform output -raw db_password)
export AWS_DEFAULT_REGION=$(terraform output -raw region)
export MODELS_BUCKET=$(terraform output -raw models_bucket)
export MIN_TRAINING_SET_SIZE=$(terraform output -raw min_training_data)
export MIN_VALIDATION_SET_SIZE=$(terraform output -raw min_validation_data)

echo "----------- 2. Running service -----------"
cd ../../labeling_and_detection_webservice
python3 service.py