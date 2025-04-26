#!/bin/bash
# Update the system
sudo apt update
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx

# Clear default Nginx page
rm -rf /var/www/html/*

# Clone your GitHub repository
cd /tmp
git clone https://github.com/2024mt03579/cc-assignment.git

# Copy website files to Nginx web root
cp -r cc-assignment/static-web-files/* /var/www/html/

# Set correct permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Restart Nginx
systemctl restart nginx