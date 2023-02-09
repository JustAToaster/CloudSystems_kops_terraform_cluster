# CloudSystems_kops_terraform_cluster
Cloud Systems project 2021/22 and later improved upon for my Computer Science Master's Thesis.

## Introduction
This project uses Terraform to define a Kubernetes cluster on AWS associated with an RDS instance.

Terraform handles the creation of the RDS instance, the VPC, security groups, S3 buckets, while the actual k8s cluster is created by kOps: values are extracted with Terraform output and applied with kOps cluster templating.

## Usage
Install [**Terraform**](https://learn.hashicorp.com/tutorials/terraform/install-cli) and [**kOps**](https://kops.sigs.k8s.io/getting_started/install/), together with the [**AWS CLI**](https://aws.amazon.com/cli/) if you haven't already, then execute the **start_cluster.sh** script in **kubernetes_cluster**.

You will be prompted multiple times to assign values to the DB username and password variables. Once the Terraform part ends, the K8S cluster creation will start and it might take up to 15 minutes for all nodes to be ready.

Once all nodes are ready, services can be loaded to the k8s cluster with **start_services.sh**. This will also update the CoreDNS ClusterRole by adding **nodes** as resources, in order to fix internet access from the Pods.

If you wish to connect to the RDS instance and use PostgreSQL, use the following command in the terraform folder (with the proper username), then put the password when asked.

`PGPASSWORD=$(terraform output -raw db_password) psql -h $(terraform output -raw rds_address) -P $(terraform output -raw rds_port) -U $(terraform output -raw db_username)`

You can connect to the EC2 instances with:

`ssh ubuntu@ec2-[public_ip].compute-1.amazonaws.com`

## Service

The service used is a YOLOv5 detection and labeling service built with Flask and can be found in [this repository](https://github.com/JustAToaster/labeling_and_detection_webservice).
A simpler service for just object detection can be found [here](https://github.com/JustAToaster/helmet_detection_webservice).

## TODO
- Lambda functions for both user reporting and initiating training tasks on SageMaker.
- SageMaker training and uploading to S3.
- Launch lambdas and the SageMaker instance with Terraform
