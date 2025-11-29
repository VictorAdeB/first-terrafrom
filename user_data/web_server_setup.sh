#!/bin/bash
yum update -y
yum install -y httpd curl

# Get instance ID from EC2 metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Download your GitHub HTML file
curl -o /var/www/html/index.html \
  https://raw.githubusercontent.com/VictorAdeB/linktree-terrafrom/main/index.html

# Replace placeholder with actual instance ID
sed -i "s/{{INSTANCE_ID}}/$INSTANCE_ID/" /var/www/html/index.html

# Start Apache
systemctl enable httpd
systemctl start httpd
