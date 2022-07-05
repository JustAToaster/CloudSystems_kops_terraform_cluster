module "dev_vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "2.77.0"
  name               = local.vpc_name
  cidr               = "172.20.0.0/16"
  azs                = local.azs
  #private_subnets    = ["10.0.1.0/24"]
  public_subnets     = ["172.20.100.0/24", "172.20.101.0/24"]
  //Disable NAT Gateway, which costs 4.5 cents/hour
  enable_nat_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true
  #create_database_subnet_group = true
  #create_database_subnet_route_table = true
  #create_database_internet_gateway_route = true

  tags = {
    // This is so kops knows that the VPC resources can be used for k8s
    "kubernetes.io/cluster/${local.kubernetes_cluster_name}" = "shared"
    "terraform"                                              = true
    "environment"                                            = local.environment
  }

  // Comment private subnet because it uses a NAT Gateway, which costs 4.5 cents/hour
  #private_subnet_tags = {
  #  "kubernetes.io/role/internal-elb" = true
  #}

  public_subnet_tags = {
    "kubernetes.io/role/elb" = true
  }
}
