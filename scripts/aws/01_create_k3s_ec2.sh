#!/bin/bash
set -e

REGION="ap-south-1"
INSTANCE_TYPE="t3.medium"
KEY_NAME="resume-rag-key"
SG_NAME="between-k3s-sg"

echo ">>> Checking / Creating Security Group: $SG_NAME in $REGION..."

SG_ID=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=$SG_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    echo "Creating Security Group $SG_NAME..."
    SG_ID=$(aws ec2 create-security-group --region $REGION --group-name $SG_NAME --description "Security group for Between k3s and ArgoCD" --query "GroupId" --output text)
    
    echo "Authorizing Inbound ports: 22, 80, 443, 6443, 8080..."
    aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_ID --protocol tcp --port 6443 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0
else
    echo "Security Group exists: $SG_ID"
fi

AMI_ID=$(aws ec2 describe-images --region $REGION --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" --output text)

echo "Using AMI: $AMI_ID"

USER_DATA=$(cat <<'EOF'
#!/bin/bash
set -e
apt-get update -y
apt-get install -y curl git ufw fail2ban
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
sleep 15
echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/ubuntu/.bashrc
EOF
)

USER_DATA_B64=$(echo "$USER_DATA" | base64 -w 0)

echo ">>> Launching EC2 Instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region $REGION \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --user-data "$USER_DATA_B64" \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=between-k3s-gitops}]' \
    --query "Instances[0].InstanceId" \
    --output text)

echo "Instance ID: $INSTANCE_ID"
echo "Waiting for instance to be in running state..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

echo "=========================================================="
echo "SUCCESS! EC2 Instance is Running!"
echo "Public IP: $PUBLIC_IP"
echo "SSH Command: ssh -i $KEY_NAME.pem ubuntu@$PUBLIC_IP"
echo "=========================================================="
