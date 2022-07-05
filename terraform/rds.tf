//Subnet used by the RDS instance
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "subnet_group_rds"
  description = "RDS subnet group"
  subnet_ids  = module.dev_vpc.public_subnets
  tags = {
    Name = "Subnet Group RDS"
  }
}

//Security group for RDS (for the RDS instance and the instances of the k8s cluster)
//Access to MySQL is public for testing purposes, but in can easily be made private for the cluster by editing the cidr blocks
resource "aws_security_group" "security_group_rds" {
  name   = "security_group_rds"
  vpc_id = module.dev_vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group RDS"
  }
  
}

resource "aws_db_parameter_group" "pg" {
  name   = "rds-pg"
  family = "mysql5.7"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

resource "aws_db_instance" "projdb" {
  identifier             = "projdb"
  instance_class         = local.instance_class
  allocated_storage      = local.allocated_storage
  engine                 = "mysql"
  engine_version         = "5.7"
  username               = local.db_username
  password               = local.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.security_group_rds.id]
  parameter_group_name   = aws_db_parameter_group.pg.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}