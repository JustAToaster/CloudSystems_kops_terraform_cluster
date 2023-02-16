#!/bin/bash

set -e -o pipefail

sudo -u ec2-user -i << 'EOF'

unset SUDO_UID
# Separate conda installation with Miniconda
WORKING_DIR=/home/ec2-user/SageMaker/custom-miniconda
mkdir -p "$WORKING_DIR"
wget https://repo.anaconda.com/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh -O "$WORKING_DIR/miniconda.sh"
bash "$WORKING_DIR/miniconda.sh" -b -u -p "$WORKING_DIR/miniconda" 
rm -rf "$WORKING_DIR/miniconda.sh"
# Variables to create the custom kernel
source "$WORKING_DIR/miniconda/bin/activate"
KERNEL_NAME="justatoaster_custom_kernel"
PYTHON="3.8"
# Creating the custom kernel
conda create --yes --name "$KERNEL_NAME" python="$PYTHON"
conda activate "$KERNEL_NAME"
# Installing the default ipykernel required from SageMaker
pip install --quiet ipykernel

# Cloning yolov5 repository
git clone https://github.com/JustAToaster/yolov5
cd yolov5
# Installing yolov5 dependencies
pip install --qr requirements.txt
EOF