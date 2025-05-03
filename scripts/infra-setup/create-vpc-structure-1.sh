#!/bin/bash
set -e

# --- Check for input parameters ---
if [ $# -lt 3 ]; then
  echo "Usage: $0 <VPC-Name> <Subnet-prefix> <SecurityGroup-Name>"
  echo "Example: $0 <vpc-name> <subnet-prefix> <vpc-sg>"
  exit 1
fi

# === Parameters from Command Line ===
VPC_NAME=$1
SUBNET_PREFIX=$2
SECURITY_GROUP_NAME=$3

# === Static Configuration ===
REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR_1="10.0.10.0/24"
SUBNET_CIDR_2="10.0.20.0/24"

echo "Starting creation with:"
echo "VPC Name: $VPC_NAME"
echo "Subnet Name: $SUBNET_PREFIX"
echo "Security Group Name: $SECURITY_GROUP_NAME"

# --- 1. Create VPC ---
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME --region $REGION

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}" --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION

# --- 2. Create Subnet in us-east-1a ---
SUBNET_ID_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_CIDR_1 \
  --availability-zone ${REGION}a \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags --resources $SUBNET_ID_1 --tags Key=Name,Value="${SUBNET_PREFIX}-A" --region $REGION

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID_1 --map-public-ip-on-launch

# --- 2b. Create Subnet in us-east-1b ---
SUBNET_ID_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_CIDR_2 \
  --availability-zone ${REGION}b \
  --region $REGION \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags --resources $SUBNET_ID_2 --tags Key=Name,Value="${SUBNET_PREFIX}-B" --region $REGION

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID_2 --map-public-ip-on-launch

# --- 3. Create Internet Gateway ---
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION

# --- 4. Create Route Table and Associate both Subnets ---
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION

aws ec2 associate-route-table --subnet-id $SUBNET_ID_1 --route-table-id $ROUTE_TABLE_ID --region $REGION
aws ec2 associate-route-table --subnet-id $SUBNET_ID_2 --route-table-id $ROUTE_TABLE_ID --region $REGION

# --- 5. Create Security Group ---
SG_ID=$(aws ec2 create-security-group \
  --group-name $SECURITY_GROUP_NAME \
  --description "Allow SSH, HTTP, HTTPS, MySQL" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3306 --cidr 0.0.0.0/0 --region $REGION

# --- 6. Create DB Subnet Group ---
DB_SUBNET_GROUP_NAME="$SUBNET_PREFIX-group"
aws rds create-db-subnet-group \
  --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
  --db-subnet-group-description "DB Subnet Group for RDS" \
  --subnet-ids $SUBNET_ID_1 $SUBNET_ID_2 \
  --region $REGION

echo "DB Subnet Group Created: $DB_SUBNET_GROUP_NAME"

# --- Output Summary ---
echo ""
echo "Resources Created Successfully!"
echo "VPC ID:             $VPC_ID "
echo "Subnet ID (AZ-a):   $SUBNET_ID_1"
echo "Subnet ID (AZ-b):   $SUBNET_ID_2"
echo "Internet Gateway:   $IGW_ID"
echo "Route Table ID:     $ROUTE_TABLE_ID"
echo "Security Group ID:  $SG_ID"
echo "DB Subnet Group:    $DB_SUBNET_GROUP_NAME"

cat <<EOF > .runner-config
vpc=$VPC_ID
subnet1=$SUBNET_ID_1
subnet2=$SUBNET_ID_2
sg=$SG_ID
db_subnet_group=$DB_SUBNET_GROUP_NAME
EOF