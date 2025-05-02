#!/bin/bash
set -e

# --- Check for input parameters ---
if [ $# -lt 3 ]; then
  echo "Usage: $0 <VPC-Name> <Subnet-Name> <SecurityGroup-Name>"
  echo "Example: $0 MyVPC MyPublicSubnet MyPublicSG"
  exit 1
fi

# === Parameters from Command Line ===
VPC_NAME=$1
SUBNET_NAME=$2
SECURITY_GROUP_NAME=$3

# === Static Configuration ===
REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"

echo "Starting creation with:"
echo "VPC Name: $VPC_NAME"
echo "Subnet Name: $SUBNET_NAME"
echo "Security Group Name: $SECURITY_GROUP_NAME"

# --- 1. Create VPC ---
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text)

# Add Name Tag
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME --region $REGION

echo "VPC Created: $VPC_ID ($VPC_NAME)"

# Enable DNS settings
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}" --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION

# --- 2. Create Subnet ---
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_CIDR \
  --region $REGION \
  --availability-zone ${REGION}a \
  --query 'Subnet.SubnetId' \
  --output text)

# Tag Subnet
aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=$SUBNET_NAME --region $REGION

echo "Subnet Created: $SUBNET_ID ($SUBNET_NAME)"

# Enable Auto-Assign Public IP
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch

# --- 3. Create Internet Gateway ---
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID \
  --region $REGION

echo "Internet Gateway Created and Attached: $IGW_ID"

# --- 4. Create Route Table and Associate ---
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Add public route
aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $REGION

# Associate Subnet to Route Table
aws ec2 associate-route-table \
  --subnet-id $SUBNET_ID \
  --route-table-id $ROUTE_TABLE_ID \
  --region $REGION

echo "Route Table Created and Subnet Associated: $ROUTE_TABLE_ID"

# --- 5. Create Security Group ---
SG_ID=$(aws ec2 create-security-group \
  --group-name $SECURITY_GROUP_NAME \
  --description "Allow SSH, HTTP, HTTPS" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

# Allow SSH
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
# Allow HTTP
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
# Allow HTTPS
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
# Allow MYSQL Port
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3306 --cidr 0.0.0.0/0 --region $REGION

echo "Security Group Created: $SG_ID ($SECURITY_GROUP_NAME)"

# --- Done ---
echo ""
echo "Resources Created Successfully!"
echo "VPC ID:           $VPC_ID "
echo "Subnet ID:        $SUBNET_ID"
echo "Internet Gateway: $IGW_ID"
echo "Route Table ID:   $ROUTE_TABLE_ID"
echo "Security Group:   $SG_ID"

cat <<EOF > .runner-config
vpc=$VPC_ID
subnet=$SUBNET_ID
sg=$SG_ID
EOF
