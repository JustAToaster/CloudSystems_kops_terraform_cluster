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

//Instances data

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