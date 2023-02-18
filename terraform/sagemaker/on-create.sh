#!/bin/bash

set -e -o pipefail

sudo -u ec2-user -i << 'EOF'

echo "Going to SageMaker directory"
cd /home/ec2-user/SageMaker/

echo "Cloning yolov5 repository"
git clone https://github.com/ultralytics/yolov5
cd yolov5

echo "Fetching the training jobs script"
curl -O https://raw.githubusercontent.com/JustAToaster/CloudSystems_kops_terraform_cluster/main/yolov5/training_jobs.py

echo "Fetching the custom YOLOv5 validation script"
curl -O https://raw.githubusercontent.com/JustAToaster/CloudSystems_kops_terraform_cluster/main/yolov5/val.py

echo "Creating conda environment from pytorch_p39"
conda create --prefix /home/ec2-user/SageMaker/envs/yolov5_p39 --clone pytorch_p39
source activate /home/ec2-user/SageMaker/envs/yolov5_p39

echo "Installing YOLOv5 dependencies"
pip install -r requirements.txt
pip install boto3

# echo "Stopping the notebook instance"
# NOTEBOOK_INSTANCE_NAME=$(jq '.ResourceName' /opt/ml/metadata/resource-metadata.json --raw-output)
# aws sagemaker stop-notebook-instance --notebook-instance-name $NOTEBOOK_INSTANCE_NAME
echo "Terminating on create lifecycle script."
EOF