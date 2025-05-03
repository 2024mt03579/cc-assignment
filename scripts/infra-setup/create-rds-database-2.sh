#!/bin/bash

# Variables
DB_INSTANCE_IDENTIFIER="ccassignmentrds"
DB_NAME=$1
DB_USER=$2
#Looking for DB_PASSWORD in the environment variable
if [ -z $DB_PASSWORD ];then
  echo "export DB_PASSWORD variable before running the script"
  exit 1
fi
DB_INSTANCE_CLASS="db.t3.micro"
DB_ENGINE="mysql"
DB_ENGINE_VERSION="8.0.35"
ALLOCATED_STORAGE=20 # in GB
REGION=$3
VPC_SECURITY_GROUP_ID=$(cat .runner-config | grep sg | awk -F "=" '{print $2}' | xargs)
SUBNET_GROUP_NAME=$(cat .runner-config | grep db_subnet_group | awk -F "=" '{print $2}' | xargs)

if [ $# -lt 3 ];then
  echo "usage: $0 <db-name> <db-user> <db-region>"
  exit 1
fi

echo $SUBNET_GROUP_NAME

aws rds describe-db-subnet-groups \
  --db-subnet-group-name "${SUBNET_GROUP_NAME}" \
  --region "$REGION"

# Create the RDS instance
aws rds create-db-instance \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --db-name $DB_NAME \
  --db-instance-class $DB_INSTANCE_CLASS \
  --engine $DB_ENGINE \
  --engine-version $DB_ENGINE_VERSION \
  --master-username $DB_USER \
  --master-user-password $DB_PASSWORD \
  --allocated-storage $ALLOCATED_STORAGE \
  --vpc-security-group-ids $VPC_SECURITY_GROUP_ID \
  --db-subnet-group-name $SUBNET_GROUP_NAME \
  --publicly-accessible \
  --region $REGION \
  --no-cli-pager

# Wait for DB to be available
echo "Waiting for RDS instance to become available..."
aws rds wait db-instance-available \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --region $REGION

# Fetch DB endpoint and port
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --region $REGION \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

DB_PORT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --region $REGION \
  --query 'DBInstances[0].Endpoint.Port' \
  --output text)

# Print connection info
echo ""
echo "RDS MySQL instance created successfully!"
echo "------------------------------------------"
echo "DB Endpoint:     $DB_ENDPOINT"
echo "DB Port:         $DB_PORT"
echo "DB Name:         $DB_NAME"
echo "DB User:         $DB_USER"
echo ""
echo "JDBC-style URL:"
echo "jdbc:mysql://$DB_ENDPOINT:$DB_PORT/$DB_NAME"
echo "------------------------------------------"


cat <<EOF > .db-config
db_endpoint=$DB_ENDPOINT
db_port=$DB_PORT
db_name=$DB_NAME
db_user=$DB_USER
db_password=$DB_PASSWORD
EOF