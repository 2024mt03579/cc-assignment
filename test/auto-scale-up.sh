#!/bin/bash
set -e

# --- Check if ASG Name is given ---
if [ $# -lt 2 ]; then
  echo "Usage: $0 <auto-scaling-group-name> <desired-capacity>"
  echo "Example: $0 my-asg-name 2"
  exit 1
fi

# --- Parameters ---
ASG_NAME=$1
NEW_DESIRED_CAPACITY=$2
REGION="us-east-1"  # Change if needed

# --- Force scaling ---
echo "Forcing Auto Scaling Group '$ASG_NAME' to Desired Capacity = $NEW_DESIRED_CAPACITY"

aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --desired-capacity "$NEW_DESIRED_CAPACITY" \
  --region "$REGION"

echo "Scaling instruction sent to ASG: $ASG_NAME"
echo "It may take 1-2 minutes for EC2 instances to spin up."