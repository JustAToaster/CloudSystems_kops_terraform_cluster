# CloudSystems_kops_terraform_cluster
Cloud Systems project 2021/22.

## Introduction
This project uses Terraform to define a Kubernetes cluster on AWS associated with an RDS instance.

Terraform handles the creation of the RDS instance, the VPC, security groups, S3 buckets, while the actual k8s cluster is created by kOps: values are extracted with Terraform output and applied with kOps cluster templating.

## Usage
Install **Terraform** and **kOps**, then execute the **start_cluster.sh** script in **kubernetes_cluster**.

You will be prompted multiple times to assign values to the DB username and password. Once the Terraform part ends, the K8S cluster creation will start and it might take up to 15 minutes for all nodes to be ready.

Once all nodes are ready, services can be loaded to the k8s cluster with **start_services.sh**. This will also update the CoreDNS ClusterRole by adding **nodes** as resources, in order to fix internet access from the Pods.

If you wish to connect to RDS instance and use MySQL, use the following command in the terraform folder (with the proper username), then put the password when asked.

`mysql -h $(terraform output -raw rds_address) -P $(terraform output -raw rds_port) -u username -p`

You can connect to the EC2 instances with:

`ssh ubuntu@ec2-[public_ip].compute-1.amazonaws.com`
