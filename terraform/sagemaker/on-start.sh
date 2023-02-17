#!/bin/bash

set -e -o pipefail

sudo -u ec2-user -i << 'EOF'
cd yolov5

conda activate python3
python3 training_jobs.py
conda deactivate

echo "Done! Scheduling notebook instance stopping."
at -f stop.sh now + 5 min
EOF