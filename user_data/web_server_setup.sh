#!/bin/bash
# Runs as root on Amazon Linux 2
yum update -y
yum install -y httpd

# Start and enable Apache
systemctl enable httpd
systemctl start httpd

# Write a simple page showing instance-id
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
cat > /var/www/html/index.html <<EOF
<html>
  <head><title>TechCorp Web Server</title></head>
  <body>
    <h1>TechCorp Web Server</h1>
    <p>Instance ID: ${INSTANCE_ID}</p>
  </body>
</html>
EOF
