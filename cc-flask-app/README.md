# Flask Application with MySQL on Docker

This is a simple Flask application that allows users to submit contact forms and stores their data in a MySQL database.

## Features
- **Contact Form**: Users can submit their name, email, and message through a contact form.
- **Database Integration**: The form data is stored in a MySQL database.
- **View Submitted Messages**: Users can view all the submitted messages from the database.
- **MySQL**: MySQL is run in a Docker container for local development or hosted using AWS RDS.

## Requirements
- **Python 3.12**
- **venv (sudo apt install python3.12-venv)**
- **Nginx** (sudo apt install nginx)
- **Docker** (for MySQL container if using)

## Setup Instructions

### 1. Clone the Repository
Clone the repository to your local machine and navigate to cc-flask-app dir

### 2. Install Python Dependencies
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows, use `venv\Scripts\activate`
pip install -r requirements.txt
```

### 3. Setup mysql docker container for local testing
```bash
docker run -p 3306:3306 --name mysql-container -e MYSQL_ROOT_PASSWORD=my-secret-password -d mysql:latest
docker exec -it mysql-container mysql -u root -p # Provide the password
```
Create the database
```mysql
create database cc_db;
```

The creation of table along with schema is handled by application

### 4. Test the application 
```bash
python app.py
```
Expected output
```bash
(venv) aditya@Aditya:/opt/cc-assignment/cc-flask-app$ python3 app.py
 * Serving Flask app 'app'
 * Debug mode: on
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on http://127.0.0.1:8000
Press CTRL+C to quit
 * Restarting with stat
 * Debugger is active!
 * Debugger PIN: 112-163-463
```

### 5. Access the application 
- Home Page (/): Displays the contact form where users can submit their details.
- Messages Page (/messages): Displays all submitted messages from the contact form.

## Production setup
Setup the following env vars 
```bash
export DB_HOST=<aws_rds_endpoint>
export DB_USER=<username>
export DB_PASSWORD=<password>
export DB_NAME=<db_name_created_during_rds_setup>
export SECRET_KEY=<some_secret_for_session_mgmt>
```
On the linux instance, either `python app.py` can be used or for more production like setup run

`gunicorn --bind 0.0.0.0:8000 app:app`

Expected output with gunicorn
```bash
(venv) aditya@Aditya:/opt/cc-assignment/cc-flask-app$ gunicorn --bind 0.0.0.0:8000 app:app
[2025-04-27 06:53:57 +0000] [3628] [INFO] Starting gunicorn 23.0.0
[2025-04-27 06:53:57 +0000] [3628] [INFO] Listening at: http://0.0.0.0:8000 (3628)
[2025-04-27 06:53:57 +0000] [3628] [INFO] Using worker: sync
[2025-04-27 06:53:57 +0000] [3629] [INFO] Booting worker with pid: 3629
```

**NOTE: The `gunicorn` is not compatible with windows**

## Nginx setup to serve traffic directly over HTTP port
- Make sure nginx is install
`sudo apt install nginx`
- Create nginx config
`sudo vim /etc/nginx/sites-available/myflaskapp`
- Add the bellow content
```bash
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```
- Link the config
`sudo ln -s /etc/nginx/sites-available/myflaskapp /etc/nginx/sites-enabled/`
- Validate the config
`sudo nginx -t`
- Start nginx if no issues in config
`sudo systemctl restart nginx`
- If there's an error like `a duplicate default server` then remove the default site by running
`sudo rm /etc/nginx/sites-enabled/default` and restart nginx service again
- 
With this, you can directly access the application on default http port using just fqdn also via NLB
e.g. http://ec2-18-212-57-31.compute-1.amazonaws.com/
or http://flask-nlb-f47755032f18a14a.elb.us-east-1.amazonaws.com/

**NOTE: This is not the most secure way but just for learning purpose**
