#!/bin/bash

set -e -o pipefail

sudo -u ec2-user -i << 'EOF'
echo "Going to SageMaker/yolov5 directory"
cd /home/ec2-user/SageMaker/yolov5

echo "Activating custom environment"
ln -s /home/ec2-user/SageMaker/envs/yolov5_p39 /home/ec2-user/anaconda3/envs/yolov5_p39
source activate /home/ec2-user/anaconda3/envs/yolov5_p39

nohup python3 training_jobs.py &
echo "Terminating on start lifecycle script. Training job will run in the background."
EOF