# Terraform Configuration for OCAI Medical AWS Infrastructure
# Este archivo crea toda la infraestructura necesaria en AWS

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "OCAI-Medical"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source para obtener VPC por defecto
data "aws_vpc" "default" {
  default = true
}

# Data source para obtener subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Obtener tu IP pública actual para SSH
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip = chomp(data.http.myip.response_body)
}

# ============================================
# SECURITY GROUPS
# ============================================

# Security Group para RDS
resource "aws_security_group" "rds" {
  name        = "ocai-rds-sg"
  description = "Security group for OCAI RDS PostgreSQL"
  vpc_id      = data.aws_vpc.default.id

  # Permitir PostgreSQL desde mi IP (desarrollo)
  ingress {
    description = "PostgreSQL from my IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip}/32"]
  }

  # Permitir PostgreSQL desde EC2 (n8n)
  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ocai-rds-sg"
  }
}

# Security Group para EC2
resource "aws_security_group" "ec2" {
  name        = "ocai-n8n-sg"
  description = "Security group for OCAI n8n EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # HTTP
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH desde mi IP
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip}/32"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ocai-n8n-sg"
  }
}

# ============================================
# RDS POSTGRESQL
# ============================================

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "ocai-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "OCAI DB Subnet Group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier     = "ocai-medical-db"
  engine         = "postgres"
  engine_version = "14.13"

  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  publicly_accessible = var.db_publicly_accessible
  skip_final_snapshot = var.db_skip_final_snapshot

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  deletion_protection = var.db_deletion_protection

  tags = {
    Name = "ocai-medical-db"
  }
}

# ============================================
# EC2 INSTANCE
# ============================================

# Obtener AMI de Ubuntu más reciente
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key Pair (usar existente o crear nuevo)
resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# Elastic IP
resource "aws_eip" "n8n" {
  domain = "vpc"

  tags = {
    Name = "ocai-n8n-eip"
  }
}

# EC2 Instance
resource "aws_instance" "n8n" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type

  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  root_block_device {
    volume_size           = var.ec2_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    db_host     = aws_db_instance.postgres.address
    db_port     = aws_db_instance.postgres.port
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
    domain_name = var.domain_name
    subdomain   = var.subdomain
    ssl_email   = var.ssl_email
  })

  tags = {
    Name = "ocai-n8n-server"
  }

  depends_on = [aws_db_instance.postgres]
}

# Asociar Elastic IP a EC2
resource "aws_eip_association" "n8n" {
  instance_id   = aws_instance.n8n.id
  allocation_id = aws_eip.n8n.id
}

# ============================================
# OUTPUTS
# ============================================

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "ec2_public_ip" {
  description = "EC2 Elastic IP"
  value       = aws_eip.n8n.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.n8n.id
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i ${var.private_key_path} ubuntu@${aws_eip.n8n.public_ip}"
}

output "n8n_url" {
  description = "n8n URL"
  value       = "https://${var.subdomain}.${var.domain_name}"
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}"
  sensitive   = true
}
