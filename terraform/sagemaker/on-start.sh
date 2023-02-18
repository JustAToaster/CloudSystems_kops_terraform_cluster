#!/bin/bash

set -e -o pipefail

sudo -u ec2-user -i << 'EOF'
cd yolov5

source activate pytorch_p39
nohup python3 training_jobs.py &
echo "Terminating on start lifecycle script"
EOF