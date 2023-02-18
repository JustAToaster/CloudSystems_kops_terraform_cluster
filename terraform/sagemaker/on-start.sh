#!/bin/bash

set -e -o pipefail

sudo -u ec2-user -i << 'EOF'
echo "Going to SageMaker/yolov5 directory"
cd /home/ec2-user/SageMaker/yolov5

echo "Activating PyTorch environment"
source activate pytorch_p39

echo "Installing YOLOv5 dependencies"
pip install -r requirements.txt
pip install boto3

nohup python3 training_jobs.py &
echo "Terminating on start lifecycle script. Training job will run in the background."
EOF