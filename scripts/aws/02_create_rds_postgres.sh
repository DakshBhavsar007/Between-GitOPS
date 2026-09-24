#!/bin/bash
set -e

REGION="ap-south-1"
DB_IDENTIFIER="between-prod-db"
DB_NAME="vishleshan"
MASTER_USER="postgres"
MASTER_PASS="SecurePassword123!"
K3S_SG_NAME="between-k3s-sg"
RDS_SG_NAME="between-rds-sg"

echo ">>> Step 1: Getting k3s Security Group ID..."
K3S_SG_ID=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=$K3S_SG_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")

if [ "$K3S_SG_ID" = "None" ] || [ -z "$K3S_SG_ID" ]; then
    echo "Error: k3s Security Group not found. Run 01_create_k3s_ec2.sh first."
    exit 1
fi

echo ">>> Step 2: Creating / Checking RDS Security Group..."
RDS_SG_ID=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=$RDS_SG_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")

if [ "$RDS_SG_ID" = "None" ] || [ -z "$RDS_SG_ID" ]; then
    RDS_SG_ID=$(aws ec2 create-security-group --region $REGION --group-name $RDS_SG_NAME --description "Security group for Between RDS PostgreSQL" --query "GroupId" --output text)
    aws ec2 authorize-security-group-ingress --region $REGION --group-id $RDS_SG_ID --protocol tcp --port 5432 --source-group $K3S_SG_ID
fi

echo ">>> Step 3: Launching AWS RDS PostgreSQL Instance ($DB_IDENTIFIER)..."
aws rds create-db-instance \
    --region $REGION \
    --db-instance-identifier $DB_IDENTIFIER \
    --db-name $DB_NAME \
    --engine postgres \
    --engine-version "15" \
    --db-instance-class db.t4g.micro \
    --master-username $MASTER_USER \
    --master-user-password $MASTER_PASS \
    --allocated-storage 20 \
    --storage-type gp3 \
    --vpc-security-group-ids $RDS_SG_ID \
    --backup-retention-period 7 \
    --no-multi-az \
    --no-publicly-accessible \
    --tags "Key=Name,Value=between-postgres-rds"

echo "Waiting for RDS instance to become available..."
aws rds wait db-instance-available --region $REGION --db-instance-identifier $DB_IDENTIFIER

ENDPOINT=$(aws rds describe-db-instances --region $REGION --db-instance-identifier $DB_IDENTIFIER --query "DBInstances[0].Endpoint.Address" --output text)

echo "=========================================================="
echo "SUCCESS! RDS PostgreSQL is available!"
echo "Endpoint: $ENDPOINT"
echo "DATABASE_URL: postgresql://$MASTER_USER:$MASTER_PASS@$ENDPOINT:5432/$DB_NAME"
echo "=========================================================="
