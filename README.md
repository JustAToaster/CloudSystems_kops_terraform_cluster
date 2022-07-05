# CloudSystems_kops_terraform_cluster
Cloud Systems project 2021/22.

## Introduction
This project uses Terraform to define a Kubernetes cluster on AWS associated with an RDS instance.

Terraform handles the creation of the RDS instance, the VPC, security groups, S3 buckets, while the actual k8s cluster is created by kOps: values are extracted with Terraform output and applied with kOps cluster templating through Helm.

## Usage
Install **Terraform** and **kOps**, then execute the start_cluster.sh script in **kubernetes_cluster**.
Services can then be loaded to the k8s cluster with start_services.sh.
