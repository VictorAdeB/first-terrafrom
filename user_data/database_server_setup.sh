#!/bin/bash
# Amazon Linux 2 Postgres install and basic setup
yum update -y
yum install -y postgresql-server postgresql-contrib

# Initialize DB (path depends on package)
postgresql-setup --initdb

# Start and enable
systemctl enable postgresql
systemctl start postgresql

# Configure to listen on all interfaces
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

# Allow password auth from private subnet range (10.0.0.0/16) - adjust as needed
echo "host    all             all             10.0.0.0/16            md5" >> /var/lib/pgsql/data/pg_hba.conf

# Restart to apply changes
systemctl restart postgresql

# Create DB user and database and set password
sudo -u postgres psql -c "CREATE USER techcorp WITH PASSWORD '${db_password}';"
sudo -u postgres psql -c "CREATE DATABASE techcorp OWNER techcorp;"
