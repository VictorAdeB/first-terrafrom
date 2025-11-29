terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.region
}

# ---------------------
# VPC
# ---------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "techcorp-vpc"
  }
}

# ---------------------
# Subnets (public & private)
# ---------------------
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[tonumber(each.key)]
  map_public_ip_on_launch = true
  tags = {
    Name = "techcorp-public-subnet-${tonumber(each.key)+1}"
  }
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[tonumber(each.key)]
  map_public_ip_on_launch = false
  tags = {
    Name = "techcorp-private-subnet-${tonumber(each.key)+1}"
  }
}

# ---------------------
# Internet Gateway and Route Table for public subnets
# ---------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "techcorp-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "techcorp-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------------------
# NAT Gateways (one per public subnet)
# ---------------------
resource "aws_eip" "nat_eip" {
  for_each = aws_subnet.public
  vpc = true
  tags = { Name = "nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "nat" {
  for_each = aws_subnet.public
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = each.value.id
  tags = { Name = "techcorp-nat-${each.key}" }
  depends_on = [aws_internet_gateway.igw]
}

# Route tables for private subnets, use NAT per AZ
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat[each.key].id
    # If nat per AZ naming mismatch, map keys. We assume same numeric key ordering.
  }
  tags = { Name = "techcorp-private-rt-${each.key}" }
}

resource "aws_route_table_association" "private_assoc" {
  for_each = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ---------------------
# Security Groups
# ---------------------
# Bastion SG - allow SSH from your IP only
resource "aws_security_group" "bastion" {
  name   = "techcorp-bastion-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "SSH from admin IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-bastion-sg" }
}

# Web SG - allow HTTP/HTTPS from anywhere, SSH from bastion only
resource "aws_security_group" "web" {
  name   = "techcorp-web-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-web-sg" }
}

# DB SG - allow Postgres only from web SG; allow SSH from bastion SG
resource "aws_security_group" "db" {
  name   = "techcorp-db-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
    description     = "Postgres from web servers"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-db-sg" }
}

# ---------------------
# AMI Lookup (Amazon Linux 2)
# ---------------------
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ---------------------
# EC2 Instances
# ---------------------
# Bastion (public)
resource "aws_eip" "bastion_eip" {
  vpc = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public[0].id
  associate_public_ip_address = true
  key_name               = var.key_name == "" ? null : var.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  tags = { Name = "techcorp-bastion" }

  # Optionally, you can add user_data to create a user/password etc.
}

resource "aws_eip_association" "bastion_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion_eip.id
}

# Web servers (private) - 2 instances, one per private subnet
resource "aws_instance" "web" {
  for_each = aws_subnet.private
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.web_instance_type
  subnet_id              = each.value.id
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_name == "" ? null : var.key_name

  user_data = file("${path.module}/user_data/web_server_setup.sh")

  tags = {
    Name = "techcorp-web-${each.key}"
  }
}

# DB server (single in private subnet 1)
resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private[0].id
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.key_name == "" ? null : var.key_name

  user_data = templatefile("${path.module}/user_data/db_server_setup.sh", {
    db_password = var.db_password
  })

  tags = {
    Name = "techcorp-db"
  }
}

# ---------------------
# Application Load Balancer (ALB)
# ---------------------
resource "aws_lb" "alb" {
  name               = "techcorp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags = { Name = "techcorp-alb" }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "techcorp-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "techcorp-web-tg" }
}

# Attach web instances to TG
resource "aws_lb_target_group_attachment" "web_attach" {
  for_each = aws_instance.web
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = each.value.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# ---------------------
# Outputs
# ---------------------
output "vpc_id" {
  value = aws_vpc.this.id
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "bastion_public_ip" {
  value = aws_eip.bastion_eip.public_ip
}
