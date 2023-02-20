# AWS kOps and Terraform cluster for YOLOv5 object detection models training, inference and fine-tuning
Cloud Systems project 2021/22 and later improved upon for my Computer Science Master's Thesis.

## Introduction
This project uses Terraform to define a Kubernetes cluster on AWS associated with an RDS instance, a SageMaker notebook instance and two lambda functions.

Terraform handles the creation of the RDS instance, the SageMaker notebook instance, the two lambda functions, the VPC, security groups, S3 buckets, while the actual k8s cluster is created by kOps: values are extracted with Terraform output and applied with kOps cluster templating to the YAML templates.

## Usage
Install [**Terraform**](https://learn.hashicorp.com/tutorials/terraform/install-cli) and [**kOps**](https://kops.sigs.k8s.io/getting_started/install/), together with the [**AWS CLI**](https://aws.amazon.com/cli/) if you haven't already. In addition to the permissions described in the kOps guide, the kops user also needs full CloudWatch, Lambda and SageMaker access.
To deploy the infrastructure to AWS, execute the **start_cluster.sh** script in **kubernetes_cluster**.

You will be prompted multiple times to assign values to the DB username and password variables. Once the Terraform part ends, the K8S cluster creation will start and it might take up to 15 minutes for all nodes to be ready.

Once all nodes are ready, the YOLOv5 labeling service can be loaded to the k8s cluster with **start_services.sh**. This will also update the CoreDNS ClusterRole by adding **nodes** as resources, in order to fix internet access from the Pods.

If you wish to connect to the RDS instance and use PostgreSQL, use the following command in the terraform folder (with the proper username), then put the password when asked.

`PGPASSWORD=$(terraform output -raw db_password) psql --host=$(terraform output -raw rds_address) --port=$(terraform output -raw rds_port) --username=$(terraform output -raw db_username) --dbname=postgres`

You can connect to the EC2 instances with:

`ssh ubuntu@ec2-[public_ip].compute-1.amazonaws.com`

## Service

The service used is a YOLOv5 detection and labeling service built with Flask and can be found in [this repository](https://github.com/JustAToaster/labeling_and_detection_webservice).
A simpler service for just object detection can be found [here](https://github.com/JustAToaster/helmet_detection_webservice).

## How it works
The K8S cluster hosts a web service that allows uploading images to the server to do inference on them with various pre-existing **YOLOv5 models**, with different output classes. After uploading an image and sending it, the inference is made on the server and the output image with bounding box images is displayed.

The predictions can be customized by the user, if they can be improved upon, with a **labeling tool** that creates bounding boxes with JavaScript client-side code. Users can also request **new object detection models** with a form, and everyone can contribute to the training data for these **pending models** by uploading an image and using the labeling tool to select each bounding box with its respective class.
The images with the corresponding labels can then be sent to the server, which communicates the request information to the database on the RDS instance. If the request involves a pre-existing model, a **customization score** is also computed and sent. After that, the training data is uploaded to the S3 bucket. The **customization score** can be interpreted as the **probability that the request is malicious**.

The PostgreSQL database on the RDS instance has various triggers, that allow classifying a user as ban-worthy after they send a certain number of malicious requests with a score above a set threshold: when that happens, the **update_reported_list AWS lambda function** is called, which updates the list of banned users stored on the S3 bucket.

A **CloudWatch event rule** that sends an event every 30 minutes triggers a **lambda function**, which checks if there is enough training data for each pre-existing model or pending model, and in that case it writes a training job to the S3 bucket and starts the **SageMaker notebook instance**. The notebook instance gets the training job from the S3 bucket, along with all the corresponding models data, trains all the models, sends the new weights to the S3 bucket and then it stops itself.

The automation of the SageMaker notebook instance is possible thanks to the **lifecycle configuration scripts**, which allow running bash code both when the instance is created and when it is started from a stopped state.
The **on-create.sh** script clones the YOLOv5 official repository and downloads the custom python scripts in this repository.
The **on-start.sh** script activates the **pytorch_p39** conda environment already available on the SageMaker notebook instance and installs the remaining YOLOv5 dependencies, then starts the training job in the background, whose progess is logged to a custom CloudWatch log stream.
