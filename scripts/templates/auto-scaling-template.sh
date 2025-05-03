#!/bin/bash

# Update the system
sudo apt update
sudo apt install -y nginx python3.12-venv git mysql-client

# Enable and start Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Set RDS DB Variables (inherited from launch template)
export DB_ENDPOINT="$DB_ENDPOINT"
export DB_PORT="$DB_PORT"
export DB_NAME="$DB_NAME"
export DB_USER="$DB_USER"
export DB_PASSWORD='$DB_PASSWORD'

# Clone the GitHub repo
cd /home/ubuntu
git clone https://github.com/2024mt03579/cc-assignment.git

# Set up Nginx config
sudo rm /etc/nginx/sites-enabled/default
sudo cp /home/ubuntu/cc-assignment/webconf/nginx.conf /etc/nginx/sites-available/myflaskapp
sudo ln -s /etc/nginx/sites-available/myflaskapp /etc/nginx/sites-enabled/

# Set up Python virtual environment (no sudo needed)
cd /home/ubuntu
python3 -m venv venv
source venv/bin/activate

# Install app requirements
pip install --upgrade pip
pip install -r /home/ubuntu/cc-assignment/cc-flask-app/requirements.txt

# Install tables if they dont exist
python3 /home/ubuntu/cc-assignment/cc-flask-app/init_db.py

# Start Gunicorn in background
cd /home/ubuntu/cc-assignment/cc-flask-app
gunicorn --bind 0.0.0.0:8000 app:app > gunicorn.log 2>&1 &

# Restart Nginx
sudo systemctl restart nginx