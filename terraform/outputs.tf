output "region" {
  value = data.aws_region.current.name
}

output "vpc_id" {
  value = module.dev_vpc.vpc_id
}

output "vpc_name" {
  value = local.vpc_name
}

output "vpc_cidr_block" {
  value = module.dev_vpc.vpc_cidr_block
}

// Public Subnets
output "public_subnet_ids" {
  value = module.dev_vpc.public_subnets
}

output "public_route_table_ids" {
  value = module.dev_vpc.public_route_table_ids
}

/* Private Subnets

output "private_subnet_ids" {
  value = module.dev_vpc.private_subnets
}

output "private_route_table_ids" {
  value = module.dev_vpc.private_route_table_ids
}

output "default_security_group_id" {
  value = module.dev_vpc.default_security_group_id
}

output "nat_gateway_ids" {
  value = module.dev_vpc.natgw_ids
}

*/

output "availability_zones" {
  value = local.azs
}

output "nodes_availability_zones" {
  value = local.nodes_azs
}

output "common_http_sg_id" {
  value = aws_security_group.k8s_common_http.id
}

output "nodes_k8s_services" {
  value = aws_security_group.nodes_k8s_services.id
}

//RDS data
output "security_group_rds_id" {
  value = aws_security_group.security_group_rds.id
}

output "rds_address" {
  value = aws_db_instance.projdb.address
}

output "rds_port" {
  value = aws_db_instance.projdb.port
}

output "db_username" {
  value = local.db_username
}

output "db_password" {
  sensitive = true
  value = local.db_password
}

// Kops data
output "kops_s3_bucket" {
  value = aws_s3_bucket.kops_state.bucket
}

output "kubernetes_cluster_name" {
  value = local.kubernetes_cluster_name
}

output "master_az" {
  value = local.master_az
}

//Instances config
output "num_masters" {
  value = local.num_masters
}

output "num_nodes" {
  value = local.num_nodes
}

output "ssh_key_name" {
  value = local.ssh_key_name
}

//Masters config
output "masters_image_id" {
  value = local.masters_image_id
}

output "masters_machine_type" {
  value = local.masters_machine_type
}

output "masters_volume_size" {
  value = local.masters_volume_size
}

output "masters_max_size" {
  value = local.masters_max_size
}

output "masters_min_size" {
  value = local.masters_min_size
}

//Nodes config
output "nodes_image_id" {
  value = local.nodes_image_id
}

output "nodes_machine_type" {
  value = local.nodes_machine_type
}

output "nodes_volume_size" {
  value = local.nodes_volume_size
}

output "nodes_max_size" {
  value = local.nodes_max_size
}

output "nodes_min_size" {
  value = local.nodes_min_size
}

//Models bucket
output "models_bucket" {
  value = local.models_data_bucket_name
}

//Lambda functions config
output "training_check_frequency_minutes" {
  value = local.training_check_frequency_minutes
}

output "training_check_schedule_lambda_function" {
  value = aws_lambda_function.training_check_schedule_lambda_function.function_name
}

output "reported_lambda_function" {
  value = aws_lambda_function.reported_lambda_function.function_name
}

//SageMaker instance
output "sagemaker_instance_name" {
  value = aws_sagemaker_notebook_instance.training_notebook_instance.name
}

output "sagemaker_instance_type" {
  value = aws_sagemaker_notebook_instance.training_notebook_instance.instance_type
}

output "sagemaker_instance_volume_size" {
  value = aws_sagemaker_notebook_instance.training_notebook_instance.volume_size
}

//Training config
output "min_new_training_data" {
  value = local.min_new_training_data
}

output "min_new_validation_data" {
  value = local.min_new_validation_data
}

output "min_training_data" {
  value = local.min_training_data
}

output "min_validation_data" {
  value = local.min_validation_data
}

output "num_training_epochs" {
  value = local.num_training_epochs
}

output "num_finetuning_epochs" {
  value = local.num_finetuning_epochs
}

output "batch_size" {
  value = local.batch_size
}