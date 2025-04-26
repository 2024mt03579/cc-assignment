#!/bin/bash

set -e

# --- Input Parameters ---
VM_NAME=$1
INSTANCE_TYPE=$2
REGION="us-east-1"

# --- Check for Parameters ---
if [ -z "$VM_NAME" ] || [ -z "$INSTANCE_TYPE" ]; then
  echo "Usage: $0 <vm-name> <instance-type>"
  echo "Example: $0 MyUbuntuServer t2.micro"
  exit 1
fi

# --- Configuration ---
KEY_NAME="bits-key"
SECURITY_GROUP_NAME="${VM_NAME}-sg"

# --- 1. Get Latest Ubuntu 22.04 AMI ID ---
echo "Fetching latest Ubuntu 22.04 LTS AMI ID..."
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
  --region $REGION \
  --output text)

echo "Found AMI ID: $AMI_ID"

# --- 2. Create Key Pair ---
#echo "Creating key pair: $KEY_NAME..."
#aws ec2 create-key-pair \
#  --key-name "$KEY_NAME" \
#  --query 'KeyMaterial' \
#  --output text > "${KEY_NAME}.pem"

#chmod 400 "${KEY_NAME}.pem"

# --- 3. Create Security Group ---
echo "Creating security group: $SECURITY_GROUP_NAME..."
SG_ID=$(aws ec2 create-security-group \
  --group-name "$SECURITY_GROUP_NAME" \
  --description "Security group for $VM_NAME" \
  --query 'GroupId' \
  --region $REGION \
  --output text)

echo "Security Group ID: $SG_ID"

# --- 4. Authorize Inbound Rules (SSH, HTTP, HTTPS) ---
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION

# --- 5. Launch EC2 Instance ---
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --region $REGION \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$VM_NAME}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched Instance ID: $INSTANCE_ID"

# --- 6. Wait for the instance to be running ---
echo "Waiting for instance to reach running state..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# --- 7. Fetch Public IP ---
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "Instance is running!"
echo "VM Name: $VM_NAME"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "SSH Command:"
echo "ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP"