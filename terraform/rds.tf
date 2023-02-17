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
//Access to PostgreSQL is public for testing purposes, but in can easily be made private for the cluster by editing the cidr blocks
resource "aws_security_group" "security_group_rds" {
  name   = "security_group_rds"
  vpc_id = module.dev_vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group RDS"
  }
  
}

resource "aws_db_parameter_group" "pg" {
  name   = "rds-pg"
  family = "postgres14"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "projdb" {
  identifier             = "projdb"
  instance_class         = local.instance_class
  allocated_storage      = local.allocated_storage
  engine                 = "postgres"
  engine_version         = "14.6"
  username               = local.db_username
  password               = local.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.security_group_rds.id]
  parameter_group_name   = aws_db_parameter_group.pg.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}

resource "aws_iam_policy" "invoke_lambda_policy" {
  name        = "invoke_lambda_policy"
  path        = "/"
  description = "A policy for granting permission to invoke a Lambda function from the RDS instance."

  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "arn:aws:lambda:*:123456789123:function:*"
      },
    ]
  })
}

resource "aws_iam_role" "rds_lambda_role" {
  name               = "rds_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_lambda_role_policy" {
  role       = aws_iam_role.rds_lambda_role.name
  policy_arn = aws_iam_policy.invoke_lambda_policy.arn
}

resource "aws_db_instance_role_association" "rds_lambda_role_attach" {
  db_instance_identifier = aws_db_instance.projdb.id
  feature_name           = "Lambda"
  role_arn               = aws_iam_role.rds_lambda_role.arn
}