# ==============================================================================
# Script 02: Provision AWS RDS PostgreSQL (Free-tier eligible)
# Region: ap-south-1 (Mumbai)
# ==============================================================================

param(
    [string]$Region = "ap-south-1",
    [string]$DBInstanceIdentifier = "between-prod-db",
    [string]$DBName = "vishleshan",
    [string]$MasterUsername = "postgres",
    [string]$MasterPassword = "SecurePassword123!",
    [string]$K3sSecurityGroupName = "between-k3s-sg",
    [string]$RDSSecurityGroupName = "between-rds-sg"
)

Write-Host ">>> Step 1: Getting k3s Security Group ID..." -ForegroundColor Cyan
$k3sSgId = aws ec2 describe-security-groups --region $Region --filters "Name=group-name,Values=$K3sSecurityGroupName" --query "SecurityGroups[0].GroupId" --output text

if ($k3sSgId -eq "None" -or [string]::IsNullOrWhiteSpace($k3sSgId)) {
    Write-Error "Could not find k3s Security Group: $K3sSecurityGroupName. Please run 01_create_k3s_ec2.ps1 first."
    exit 1
}

Write-Host "k3s Security Group ID: $k3sSgId" -ForegroundColor Green

# Create RDS Security Group allowing 5432 from k3s SG
Write-Host ">>> Step 2: Creating / Checking RDS Security Group..." -ForegroundColor Cyan
$rdsSgId = aws ec2 describe-security-groups --region $Region --filters "Name=group-name,Values=$RDSSecurityGroupName" --query "SecurityGroups[0].GroupId" --output text

if ($rdsSgId -eq "None" -or [string]::IsNullOrWhiteSpace($rdsSgId)) {
    $rdsSgId = aws ec2 create-security-group --region $Region --group-name $RDSSecurityGroupName --description "Security group for Between RDS PostgreSQL" --query "GroupId" --output text
    aws ec2 authorize-security-group-ingress --region $Region --group-id $rdsSgId --protocol tcp --port 5432 --source-group $k3sSgId
    Write-Host "Created RDS Security Group: $rdsSgId" -ForegroundColor Green
} else {
    Write-Host "RDS Security Group exists: $rdsSgId" -ForegroundColor Green
}

# Launch RDS PostgreSQL instance
Write-Host ">>> Step 3: Launching AWS RDS PostgreSQL Instance ($DBInstanceIdentifier)..." -ForegroundColor Cyan

aws rds create-db-instance `
    --region $Region `
    --db-instance-identifier $DBInstanceIdentifier `
    --db-name $DBName `
    --engine postgres `
    --engine-version "15" `
    --db-instance-class db.t4g.micro `
    --master-username $MasterUsername `
    --master-user-password $MasterPassword `
    --allocated-storage 20 `
    --storage-type gp3 `
    --vpc-security-group-ids $rdsSgId `
    --backup-retention-period 7 `
    --no-multi-az `
    --no-publicly-accessible `
    --tags "Key=Name,Value=between-postgres-rds"

Write-Host "Database creation initiated! Waiting for DB instance to become available (this typically takes 5-10 minutes)..." -ForegroundColor Yellow

aws rds wait db-instance-available --region $Region --db-instance-identifier $DBInstanceIdentifier

$endpoint = aws rds describe-db-instances --region $Region --db-instance-identifier $DBInstanceIdentifier --query "DBInstances[0].Endpoint.Address" --output text

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "SUCCESS! RDS PostgreSQL is available!" -ForegroundColor Green
Write-Host "Endpoint: $endpoint" -ForegroundColor Cyan
Write-Host "DATABASE_URL: postgresql://$MasterUsername:$MasterPassword@$endpoint:5432/$DBName" -ForegroundColor Yellow
Write-Host "Update this DATABASE_URL inside your Kubernetes secrets.yaml!" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
