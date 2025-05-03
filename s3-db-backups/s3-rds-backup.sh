#!/bin/bash

# Usage: ./export-rds-snapshot-to-s3.sh <snapshot-arn>

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <rds-snapshot-arn>"
  exit 1
fi

SNAPSHOT_ARN="$1"
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DATE_SUFFIX=$(date +%Y%m%d%H%M%S)

BUCKET_NAME="rds-backup-bucket-${DATE_SUFFIX}"
EXPORT_TASK_NAME="export-task-${DATE_SUFFIX}"
IAM_ROLE_NAME="RDSExportToS3Role"
IAM_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${IAM_ROLE_NAME}"

# Use the KMS key created earlier
KMS_KEY_ARN="arn:aws:kms:${AWS_REGION}:${ACCOUNT_ID}:key/9f61a433-dd0d-4cf2-9c45-0e0cb6c6a01d"  # replace this with your actual key ARN

echo "Creating S3 bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION

echo "Starting export task: $EXPORT_TASK_NAME"
aws rds start-export-task \
  --export-task-identifier "$EXPORT_TASK_NAME" \
  --source-arn "$SNAPSHOT_ARN" \
  --s3-bucket-name "$BUCKET_NAME" \
  --iam-role-arn "$IAM_ROLE_ARN" \
  --kms-key-id "$KMS_KEY_ARN" \
  --region "$AWS_REGION"

echo "Export task started!"
echo "Monitor progress with:"
echo "aws rds describe-export-tasks --region $AWS_REGION"