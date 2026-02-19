# Variables para Terraform Configuration

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# ============================================
# RDS Variables
# ============================================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "n8n_db"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_publicly_accessible" {
  description = "Whether the DB is publicly accessible"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

# ============================================
# EC2 Variables
# ============================================

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ec2_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "ocai-key-pair-aws"
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# ============================================
# n8n Variables
# ============================================

variable "domain_name" {
  description = "Domain name for n8n"
  type        = string
  default     = "ocaihealth.com"
}

variable "subdomain" {
  description = "Subdomain for n8n"
  type        = string
  default     = "n8n"
}

variable "ssl_email" {
  description = "Email for SSL certificate"
  type        = string
  default     = "operation@ocaihealth.com"
}
