# ==============================================================================
# Script 01: Provision AWS EC2 Instance with k3s Pre-installed
# Region: ap-south-1 (Mumbai)
# ==============================================================================

param(
    [string]$Region = "ap-south-1",
    [string]$InstanceType = "t3.medium",
    [string]$KeyName = "resume-rag-key",
    [string]$SecurityGroupName = "between-k3s-sg"
)

Write-Host ">>> Checking / Creating Security Group: $SecurityGroupName in $Region..." -ForegroundColor Cyan

# 1. Check or Create Security Group
$sgId = aws ec2 describe-security-groups --region $Region --filters "Name=group-name,Values=$SecurityGroupName" --query "SecurityGroups[0].GroupId" --output text

if ($sgId -eq "None" -or [string]::IsNullOrWhiteSpace($sgId)) {
    Write-Host "Creating Security Group $SecurityGroupName..." -ForegroundColor Yellow
    $sgId = aws ec2 create-security-group --region $Region --group-name $SecurityGroupName --description "Security group for Between k3s and ArgoCD" --query "GroupId" --output text
    
    # Authorize ports: SSH (22), HTTP (80), HTTPS (443), K3s API (6443), ArgoCD UI (8080)
    Write-Host "Adding Inbound Rules (22, 80, 443, 6443, 8080)..." -ForegroundColor Yellow
    aws ec2 authorize-security-group-ingress --region $Region --group-id $sgId --protocol tcp --port 22 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --region $Region --group-id $sgId --protocol tcp --port 80 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --region $Region --group-id $sgId --protocol tcp --port 443 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --region $Region --group-id $sgId --protocol tcp --port 6443 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --region $Region --group-id $sgId --protocol tcp --port 8080 --cidr 0.0.0.0/0
} else {
    Write-Host "Security Group already exists with ID: $sgId" -ForegroundColor Green
}

# 2. Get latest Ubuntu 24.04 AMI
Write-Host ">>> Fetching latest Ubuntu 24.04 AMI in $Region..." -ForegroundColor Cyan
$amiId = aws ec2 describe-images --region $Region --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" --output text

Write-Host "Using AMI: $amiId" -ForegroundColor Green

# 3. Create UserData script for automated k3s installation
$userDataScript = @"
#!/bin/bash
set -e
apt-get update -y
apt-get install -y curl git ufw fail2ban

# Install k3s with kubeconfig world-readable for ec2-user/ubuntu
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

# Wait for k3s node to be ready
sleep 15
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Create bash alias for ubuntu user
echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/ubuntu/.bashrc
"@

$userDataBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userDataScript))

# 4. Launch EC2 Instance
Write-Host ">>> Launching EC2 Instance ($InstanceType, 30GB gp3) with key $KeyName..." -ForegroundColor Cyan

$instanceId = aws ec2 run-instances `
    --region $Region `
    --image-id $amiId `
    --instance-type $InstanceType `
    --key-name $KeyName `
    --security-group-ids $sgId `
    --user-data $userDataBase64 `
    --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":30,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=between-k3s-gitops}]" `
    --query "Instances[0].InstanceId" `
    --output text

Write-Host "Launched Instance ID: $instanceId" -ForegroundColor Green
Write-Host "Waiting for instance to enter 'running' state..." -ForegroundColor Yellow

aws ec2 wait instance-running --region $Region --instance-ids $instanceId

$publicIp = aws ec2 describe-instances --region $Region --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "SUCCESS! EC2 Instance is Running!" -ForegroundColor Green
Write-Host "Public IP: $publicIp" -ForegroundColor Cyan
Write-Host "SSH Command: ssh -i $KeyName.pem ubuntu@$publicIp" -ForegroundColor Cyan
Write-Host "Wait ~60 seconds for k3s cloud-init bootstrap to complete." -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
