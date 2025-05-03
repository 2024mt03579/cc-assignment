
# 🚀 AWS Auto Scaling Infrastructure Setup

This repository provides step-by-step scripts to provision an AWS cloud-based web application that leverages Auto Scaling, RDS, CloudWatch Alarms, and S3 for a scalable and resilient architecture.

---

## 🛠️ Prerequisites

Ensure you have the following tools installed and configured:

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- Valid AWS credentials configured using `aws configure`
- Unix-based terminal (Linux/macOS)
- Bash Shell

---

## 📌 Overview of the Steps

1. **Create VPC, Subnet, and Security Groups**
2. **Provision RDS MySQL Database**
3. **Configure EC2 Auto Scaling Launch Template**
4. **Set up Auto Scaling Group (ASG), Network Load Balancer (NLB), Target Groups, and CloudWatch Alarms**
5. **Store Static Assets in S3**
6. **Simulate High CPU Load to Trigger Auto Scaling**

---

## 1️⃣ Create VPC, Subnet & Security Groups

Run the script to create networking components:

```bash
scripts/infra-setup/create-vpc-structure-1.sh <VPC-Name> <Subnet-Name> <SecurityGroup-Name>
```

🔹 **Parameters:**
- `<VPC-Name>`: Name of the Virtual Private Cloud
- `<Subnet-Name>`: Name for the default subnet
- `<SecurityGroup-Name>`: Name of the security group to be created

---

## 2️⃣ Create RDS MySQL Database

Provision an RDS MySQL instance using:

```bash
scripts/infra-setup/create-rds-database-2.sh <db-name> <db-user> <region>
```

🔹 **Parameters:**
- `<db-name>`: Name of your database
- `<db-user>`: Master username for the DB
- `<region>`: AWS region to deploy the RDS instance

---

## 3️⃣ Auto Scaling User Data Template

A user data script that installs necessary packages and clones the web application from GitHub.

🗂 **Script Path**:
```bash
scripts/templates/auto-scaling-template.sh
```

🔧 This script is attached to the EC2 instances via the launch template.

---

## 4️⃣ Set Up ASG, NLB, CloudWatch Alarms

Run the following to configure all scaling and load balancing infrastructure:

```bash
scripts/infra-setup/create-asg-nlb.sh
```

This will:

- Create an **Auto Scaling Group** with:
  - Min instances: `1`
  - Max instances: `3`
- Create a **Launch Template** defining EC2 configuration and `user-data`
- Set up a **Network Load Balancer** (NLB) with:
  - Target group linked to the ASG
  - Listener for routing traffic
- Define **CloudWatch Alarms**:
  - `high-cpu-alarm`: Triggers scale-out at 70% average CPU usage
  - `low-cpu-alarm`: Triggers scale-in when CPU falls below threshold

---

## 5️⃣ DB Backups and Static Content in S3 Bucket

- RDS DB Snapshot backups to S3 bucket
- Static files such as logs and videos are stored in an Amazon S3 bucket for persistent and scalable storage.

---

## 6️⃣ Trigger Auto Scaling Manually (High CPU Simulation)

Use the following utility script to simulate high CPU usage and test the scaling behavior:

```bash
test/stress-vm-to-scale.sh
```

📌 Uses the `stress` utility to artificially load CPU and trigger the `high-cpu-alarm`.

```
aws cloudwatch describe-alarm-history --alarm-name high-cpu-alarm --max-items 3
```

---

## ✅ Outputs and Observability

- Monitor scaling events via **CloudWatch Console**
```
aws cloudwatch describe-alarm-history --alarm-name high-cpu-alarm --max-items 3
```

- Check ASG and instance states in the **EC2 Auto Scaling section**
- View logs on instances or in the associated **S3 bucket** (if configured)

---

## 📎 Notes

- Ensure IAM permissions are correctly assigned to allow Auto Scaling, Load Balancer, and CloudWatch operations.
- All resources are created using **AWS CLI** to maintain flexibility and transparency.

---

## 📚 References

- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/ec2/userguide/what-is-amazon-ec2-auto-scaling.html)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [AWS CLI User Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html)