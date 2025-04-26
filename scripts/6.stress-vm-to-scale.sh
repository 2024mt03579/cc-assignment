#!/bin/bash
set -e

# === Config ===
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION="us-east-1"
ALARM_NAME="high-cpu-alarm"
STRESS_DURATION=1200 # seconds (20 minutes)

echo "Starting CPU stress and monitoring script..."

# --- Step 1: Install stress tool ---
echo "Installing 'stress' package..."
sudo apt update -y
sudo apt install -y stress

# --- Step 2: Start stressing CPU ---
echo "Stressing CPU now for $STRESS_DURATION seconds..."
stress --cpu 2 --timeout $STRESS_DURATION &
STRESS_PID=$!

# --- Step 3: Monitor CloudWatch Alarm Status ---
echo "Monitoring CloudWatch Alarm: $ALARM_NAME"

while true; do
  ALARM_STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --region "$REGION" \
    --query "MetricAlarms[0].StateValue" \
    --output text)

  echo "Current Alarm State: $ALARM_STATE"

  if [[ "$ALARM_STATE" == "ALARM" ]]; then
    echo "Alarm triggered! (CPU load detected)"
    echo "Auto Scaling should start now!"
    break
  fi

  sleep 60 # Wait 1 minute before checking again
done

# --- Step 4: Confirm Scaling Activity ---
echo "Checking Auto Scaling Activities..."

aws autoscaling describe-scaling-activities \
  --region "$REGION" \
  --query "Activities[*].[StartTime,StatusCode,Description]" \
  --output table

# --- Step 5: Cleanup (optional) ---
echo "Stopping CPU stress..."
kill $STRESS_PID || true

echo "Script Completed Successfully!"
