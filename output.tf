
# ---------------------
# Outputs
# ---------------------
# output "vpc_id" {
#   value = aws_vpc.this.id
# }

# output "alb_dns_name" {
#   value = aws_lb.alb.dns_name
# }

# output "bastion_public_ip" {
#   value = aws_eip.bastion_eip.public_ip
# }

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.alb.dns_name
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = aws_eip.bastion_eip.public_ip
}
