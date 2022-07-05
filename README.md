# CloudSystems_kops_terraform_cluster
Cloud Systems project 2021/22.

## Introduction
This project uses Terraform to define a Kubernetes cluster on AWS associated with an RDS instance.

Terraform handles the creation of the RDS instance, the VPC, security groups, S3 buckets, while the actual k8s cluster is created by kOps: values are extracted with Terraform output and applied with kOps cluster templating through Helm.

## Usage
Install **Terraform** and **kOps**, then execute the **start_cluster.sh** script in **kubernetes_cluster**.

You will be prompted multiple times to assign values to the DB username and password.

To connect to RDS instance and use MySQL, use the following command in the terraform folder (with the proper username), then put the password when asked.

`mysql -h $(terraform output -raw rds_address) -P $(terraform output -raw rds_port) -u username -p`

You can connect to the EC2 instances with:

`ssh ubuntu@ec2-[public_ip].compute-1.amazonaws.com`

Services can then be loaded to the k8s cluster with **start_services.sh**.

## TODO
- Implement actual services (like ML demos)
- Use GitHub actions to update them when needed
