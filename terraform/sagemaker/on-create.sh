#!/bin/bash

set -e -o pipefail

sudo -u ec2-user -i << 'EOF'

echo "Going to SageMaker directory"
cd /home/ec2-user/SageMaker/
mkdir envs

echo "Cloning yolov5 repository"
git clone https://github.com/ultralytics/yolov5
cd yolov5

echo "Fetching the training jobs script"
curl -O https://raw.githubusercontent.com/JustAToaster/CloudSystems_kops_terraform_cluster/main/yolov5/training_jobs.py

echo "Fetching the custom YOLOv5 validation script"
curl -O https://raw.githubusercontent.com/JustAToaster/CloudSystems_kops_terraform_cluster/main/yolov5/val.py

echo "Terminating on create lifecycle script."
EOF