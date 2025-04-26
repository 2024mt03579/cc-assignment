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

if [ ! -f .runner-config ]; then
  echo "Create VPC using the script $0/create-vpc-structure.sh before proceeding"
  exit 1
fi

# --- Configuration ---
KEY_NAME="bits-key"
SECURITY_GROUP_ID=$(cat .runner-config | grep sg | awk -F "=" '{print $2}')
SUBNET_ID=$(cat .runner-config | grep subnet | awk -F "=" '{print $2}')

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

# --- 5. Launch EC2 Instance ---
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --region $REGION \
  --key-name "$KEY_NAME" \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SECURITY_GROUP_ID" \
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