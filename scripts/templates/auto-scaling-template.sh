#!/bin/bash
# Update the system
sudo apt update
sudo apt install nginx -y
sudo apt install python3.12-venv -y
sudo systemctl enable nginx
sudo systemctl start nginx

# Set RDS DB Variables that will replaced by the autoscaling template
export DB_HOST="{{DB_ENDPOINT}}"
export DB_PORT="{{DB_PORT}}"
export DB_NAME="{{DB_NAME}}"
export DB_USER="{{DB_USER}}"
export DB_PASSWORD="{{DB_PASSWORD}}"

# Clone your GitHub repository
sudo cd $HOME
sudo git clone -b initial-work-branch https://github.com/2024mt03579/cc-assignment.git

# Clear default Nginx page
sudo rm /etc/nginx/sites-enabled/default

# Prepare custom site
sudo cp $HOME/cc-assignment/webconf/nginx.conf /etc/nginx/sites-available/myflaskapp
sudo ln -s /etc/nginx/sites-available/myflaskapp /etc/nginx/sites-enabled/

# Install python app requirements
sudo python3 -m venv venv
sudo source venv/bin/activate 
sudo pip install -r $HOME/cc-assignment/cc-flask-app/requirements.txt

# Start gunicorn service in the background
sudo cd $HOME/cc-assignment/cc-flask-app 
sudo gunicorn --bind 0.0.0.0:8000 app:app > gunicorn.log 2>&1 &

# Restart nginx service
sudo systemctl restart nginx