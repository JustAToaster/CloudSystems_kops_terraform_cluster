provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "tf-state-dani-proj"
    key    = "dev/terraform"
    region = "us-east-1"
  }
}

locals {
  azs                    = ["us-east-1a", "us-east-1b"]
  //Because of free tier limitations (bandwidth between AZs), the nodes will actually be created in the same AZ as the master and the RDS instance
  nodes_azs                    = ["us-east-1a"]
  master_az                    = "us-east-1a"
  environment            = "dev-kops-proj"
  kops_state_bucket_name = "kops-config-s3"
  models_data_bucket_name = "justatoaster-yolov5-models"
  training_data_bucket_name = "justatoaster-yolov5-training-data"

  kubernetes_cluster_name = "terraform-kops-proj.k8s.local"
  ingress_ips             = ["10.0.0.100/32", "10.0.0.101/32"]
  vpc_name                = "${local.environment}-vpc"

  //Database information: will be asked when executing terraform plan, apply or destroy, or it can be loaded from environment variables
  db_username = var.db_username
  db_password = var.db_password
  allocated_storage = 5
  instance_class = "db.t2.micro"
  ssh_key_name = "dani-keypair-2022"

  tags = {
    environment = local.environment
    terraform   = true
  }
}

data "aws_region" "current" {}