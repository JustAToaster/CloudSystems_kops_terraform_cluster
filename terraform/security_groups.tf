// Used to allow web access to the k8s API ELB
resource "aws_security_group" "k8s_common_http" {
  name   = "${local.environment}_k8s_common_http"
  vpc_id = module.dev_vpc.vpc_id
  tags   = "${merge(local.tags)}"

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = local.ingress_ips
  }

  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = local.ingress_ips
  }

}

# Security group for accessing services through nodes
resource "aws_security_group" "nodes_k8s_services" {
  name   = "${local.environment}_k8s_services"
  vpc_id = module.dev_vpc.vpc_id
  tags   = "${merge(local.tags)}"

  # Allow access to services
  ingress {
    from_port   = 30000
    protocol    = "tcp"
    to_port     = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

}
