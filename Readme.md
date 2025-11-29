# Terraform Assessment - TechCorp

## Prerequisites
- Terraform v1.3+ installed
- AWS CLI configured with credentials (or environment variables)
- An existing EC2 key pair in the target region if you plan to SSH with keys
- Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in `key_name`, `my_ip` and **do not** commit secrets.

## Files
- `main.tf` - main resource definitions
- `variables.tf` - variables
- `outputs.tf` - outputs
- `user_data/` - scripts for web and db setup
- `terraform.tfvars.example` - example variable values

## Deploy
1. Initialize terraform:
   ```bash
   terraform init
