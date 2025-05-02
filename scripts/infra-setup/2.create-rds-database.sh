#!/bin/bash

# Variables (edit as needed)
DB_INSTANCE_IDENTIFIER="cc-assignment-db"
DB_NAME="${1}"
DB_USER="${2}"
DB_PASSWORD="${3}"     # Ensure it meets RDS password policy
DB_INSTANCE_CLASS="db.t3.micro"
DB_ENGINE="mysql"
DB_ENGINE_VERSION="8.0.35"
ALLOCATED_STORAGE=20                 # in GB
REGION="${4}"
VPC_SECURITY_GROUP_ID=$(cat .runner-config | grep sg | awk -F "=" '{print $2}')
SUBNET_GROUP_NAME=$(cat .runner-config | grep subnet | awk -F "=" '{print $2}')

if [ $# -lt 4 ];then
  echo "usage: $0 <db-name> <db-user> <db-password> <db-region>"

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
  --region $REGION

# Wait for DB to be available (optional)
echo "Waiting for RDS instance to become available..."
aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_IDENTIFIER --region $REGION

# Fetch endpoint
echo "RDS MySQL instance created. Endpoint details:"
aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --region $REGION \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text