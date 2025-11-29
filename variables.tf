variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "AZs to use (2 required)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (2)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (2)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "Instance type for web servers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "Instance type for database server"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name to use for SSH access"
  type        = string
  default     = ""
}

variable "my_ip" {
  description = "Your public IP for bastion SSH access"
  type        = string
  default     = "105.112.10.67"  # WARNING: opens SSH to the world
}


variable "db_password" {
  description = "Postgres password for the DB server (sensitive)"
  type        = string
  sensitive   = true
  default     = ""
}
