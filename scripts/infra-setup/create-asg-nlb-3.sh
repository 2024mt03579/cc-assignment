#!/bin/bash
set -e

# === CONFIGURABLE PARAMETERS ===
VM_NAME="as-web-app"
INSTANCE_TYPE="t2.micro"
KEY_NAME="bits-key"
VPC_ID=$(cat .runner-config | grep vpc | awk -F "=" '{print $2}')
SECURITY_GROUP_ID=$(cat .runner-config | grep sg | awk -F "=" '{print $2}')
SUBNET_ID=$(cat .runner-config | grep subnet1 | awk -F "=" '{print $2}')
LAUNCH_TEMPLATE_NAME="${VM_NAME}-lt"
ASG_NAME="${VM_NAME}-asg"
TARGET_GROUP_NAME="${VM_NAME}-tg"
NLB_NAME="${VM_NAME}-nlb"
REGION="us-east-1"

# === READ RDS CONFIG TO PASS TO LAUNCH TEMPLATE ===
export DB_ENDPOINT=$(cat .db-config | grep db_endpoint | awk -F "=" '{print $2}')
export DB_PORT=$(cat .db-config | grep db_port | awk -F "=" '{print $2}')
export DB_NAME=$(cat .db-config | grep db_name | awk -F "=" '{print $2}')
export DB_USER=$(cat .db-config | grep db_user | awk -F "=" '{print $2}')
export DB_PASSWORD=$(cat .db-config | grep db_password | awk -F "=" '{print $2}')

# === END OF CONFIGURATION ===

# --- 1. Fetch Latest Ubuntu 24.04 AMI ID ---
echo "Fetching latest Ubuntu 24.04 LTS AMI ID..."
AMI_ID="ami-084568db4383264d4"

# --- 6. Fetch User-Data from GitHub ---
echo "Fetching User Data from GitHub..."
curl -s https://raw.githubusercontent.com/2024mt03579/cc-assignment/main/scripts/templates/auto-scaling-template.sh -o user-data.template.sh
envsubst < user-data.template.sh > user-data.sh
USER_DATA_BASE64=$(base64 -w 0 user-data.sh)

# --- 7. Create Launch Template ---
echo "Creating Launch Template..."
aws ec2 create-launch-template \
  --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
  --version-description "v1" \
  --launch-template-data "{
    \"ImageId\":\"$AMI_ID\",
    \"InstanceType\":\"$INSTANCE_TYPE\",
    \"KeyName\":\"$KEY_NAME\",
    \"SecurityGroupIds\":[\"$SECURITY_GROUP_ID\"],
    \"UserData\":\"$USER_DATA_BASE64\"
  }" \
  --region "$REGION"

# --- 8. Create Target Group for NLB ---
echo "Creating Target Group..."
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
  --name "$TARGET_GROUP_NAME" \
  --protocol TCP \
  --port 80 \
  --vpc-id "$VPC_ID" \
  --target-type instance \
  --region "$REGION" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# --- 9. Create NLB ---
echo "Creating Network Load Balancer..."
NLB_ARN=$(aws elbv2 create-load-balancer \
  --name "$NLB_NAME" \
  --type network \
  --subnets $SUBNET_ID \
  --region "$REGION" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# --- 10. Create Listener for NLB ---
echo "Creating Listener for NLB..."
aws elbv2 create-listener \
  --load-balancer-arn "$NLB_ARN" \
  --protocol TCP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" \
  --region "$REGION"

# --- 11. Create Auto Scaling Group ---
echo "Creating Auto Scaling Group..."
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --launch-template LaunchTemplateName="$LAUNCH_TEMPLATE_NAME",Version=1 \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 1 \
  --vpc-zone-identifier "$(echo $SUBNET_ID | tr ' ' ',')" \
  --target-group-arns "$TARGET_GROUP_ARN" \
  --region "$REGION"

# --- 12. Create Scaling Policies and CloudWatch Alarms ---
echo "Setting up Scaling Policies..."

# Scale Out Policy
SCALE_OUT_POLICY_ARN=$(aws autoscaling put-scaling-policy \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-name "cpu-scale-out" \
  --scaling-adjustment 1 \
  --adjustment-type ChangeInCapacity \
  --region "$REGION" \
  --query 'PolicyARN' \
  --output text)

# Alarm for Scale Out
aws cloudwatch put-metric-alarm \
  --alarm-name "high-cpu-alarm" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=AutoScalingGroupName,Value="$ASG_NAME" \
  --evaluation-periods 2 \
  --alarm-actions "$SCALE_OUT_POLICY_ARN" \
  --region "$REGION"

# Scale In Policy
SCALE_IN_POLICY_ARN=$(aws autoscaling put-scaling-policy \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-name "cpu-scale-in" \
  --scaling-adjustment -1 \
  --adjustment-type ChangeInCapacity \
  --region "$REGION" \
  --query 'PolicyARN' \
  --output text)

# Alarm for Scale In
aws cloudwatch put-metric-alarm \
  --alarm-name "low-cpu-alarm" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 30 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=AutoScalingGroupName,Value="$ASG_NAME" \
  --evaluation-periods 2 \
  --alarm-actions "$SCALE_IN_POLICY_ARN" \
  --region "$REGION"

echo "All resources created successfully!"