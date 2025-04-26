#!/bin/bash
set -e

# === CONFIGURABLE PARAMETERS ===
VM_NAME="as-web-app"
INSTANCE_TYPE="t2.micro"
KEY_NAME="${VM_NAME}-key"
SECURITY_GROUP_NAME="${VM_NAME}-sg"
LAUNCH_TEMPLATE_NAME="${VM_NAME}-lt"
ASG_NAME="${VM_NAME}-asg"
TARGET_GROUP_NAME="${VM_NAME}-tg"
NLB_NAME="${VM_NAME}-nlb"
REGION="us-east-1"

# === END OF CONFIGURATION ===

# --- 1. Fetch Latest Ubuntu 22.04 AMI ID ---
echo "Fetching latest Ubuntu 22.04 LTS AMI ID..."
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
  --region "$REGION" \
  --output text)
echo "Using AMI ID: $AMI_ID"

# --- 2. Get Default VPC ID ---
echo "Fetching default VPC ID..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --region "$REGION" \
  --query "Vpcs[0].VpcId" \
  --output text)
echo "Default VPC ID: $VPC_ID"

# --- 3. Get Subnets in Default VPC ---
echo "Fetching Subnets for Default VPC..."
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --region "$REGION" \
  --query "Subnets[*].SubnetId" \
  --output text)
echo "Subnet IDs: $SUBNET_IDS"

# --- 4. Create Key Pair ---
echo "Creating Key Pair..."
aws ec2 create-key-pair \
  --key-name "$KEY_NAME" \
  --query 'KeyMaterial' \
  --region "$REGION" \
  --output text > "${KEY_NAME}.pem"
chmod 400 "${KEY_NAME}.pem"

# --- 5. Create Security Group ---
echo "Creating Security Group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name "$SECURITY_GROUP_NAME" \
  --description "Allow SSH, HTTP, HTTPS" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --output text)

# Allow SSH, HTTP, HTTPS
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0 --region "$REGION"

# --- 6. Fetch User-Data from GitHub ---
echo "Fetching User Data from GitHub..."
curl -s https://raw.githubusercontent.com/2024mt03579/cc-assignment/main/scripts/auto-scaling-template.sh -o user-data.sh
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
    \"SecurityGroupIds\":[\"$SG_ID\"],
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
  --subnets $SUBNET_IDS \
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
  --vpc-zone-identifier "$(echo $SUBNET_IDS | tr ' ' ',')" \
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