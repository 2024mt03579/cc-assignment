#!/bin/bash

# Usage: ./export-rds-snapshot-to-s3.sh <snapshot-arn>

# Exit on error
set -e

# Check if snapshot ARN is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <rds-snapshot-arn>"
  exit 1
fi

# Input variables
SNAPSHOT_ARN="$1"
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DATE_SUFFIX=$(date +%Y%m%d%H%M%S)

# Derived values
BUCKET_NAME="rds-backup-bucket-${DATE_SUFFIX}"
EXPORT_TASK_NAME="export-task-${DATE_SUFFIX}"
IAM_ROLE_NAME="rds-s3-export-role"
KMS_KEY_ARN="arn:aws:kms:${AWS_REGION}:${ACCOUNT_ID}:key/493b148e-1235-4777-9e1f-9dd039100b39"  # Replace with your KMS key

# Create the S3 bucket
echo "Creating S3 bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION

# Create IAM role and policy if needed
IAM_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${IAM_ROLE_NAME}"

# Start export snapshot to S3
echo "Starting export task: $EXPORT_TASK_NAME"
aws rds export-snapshot \
  --export-task-identifier "$EXPORT_TASK_NAME" \
  --source-arn "$SNAPSHOT_ARN" \
  --s3-bucket-name "$BUCKET_NAME" \
  --iam-role-arn "$IAM_ROLE_ARN" \
  --kms-key-id "$KMS_KEY_ARN" \
  --region "$AWS_REGION"

echo "Export task started. Monitor it with:"
echo "aws rds describe-export-tasks --region $AWS_REGION"