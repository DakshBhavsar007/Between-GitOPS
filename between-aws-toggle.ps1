<#
.SYNOPSIS
    Between-GitOps AWS Cost Management Toggle

.DESCRIPTION
    Double-click this script to toggle ALL Between-GitOps AWS resources:
      - EC2 Instance: i-0b49f1e35eeca2dc2 (k3s cluster)
      - RDS Instance: between-prod-db (PostgreSQL)

    If resources are RUNNING  -> STOPS them (saves money)
    If resources are STOPPED  -> STARTS them (back online)

    The script auto-detects the current state and toggles accordingly.

.NOTES
    Region: ap-south-1
    Requires: AWS CLI configured with appropriate credentials
#>

# -- Configuration --
$AWS_REGION        = "ap-south-1"
$EC2_INSTANCE_ID   = "i-0b49f1e35eeca2dc2"
$RDS_INSTANCE_ID   = "between-prod-db"
$PROJECT_NAME      = "Between-GitOps"

# -- Helper Functions --

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ======================================================" -ForegroundColor Cyan
    Write-Host "  |       Between-GitOps  --  AWS Cost Manager          |" -ForegroundColor Cyan
    Write-Host "  ======================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-EC2State {
    try {
        $state = aws ec2 describe-instances `
            --instance-ids $EC2_INSTANCE_ID `
            --region $AWS_REGION `
            --query "Reservations[0].Instances[0].State.Name" `
            --output text 2>&1
        return $state.Trim()
    } catch {
        return "error"
    }
}

function Get-RDSState {
    try {
        $state = aws rds describe-db-instances `
            --db-instance-identifier $RDS_INSTANCE_ID `
            --region $AWS_REGION `
            --query "DBInstances[0].DBInstanceStatus" `
            --output text 2>&1
        return $state.Trim()
    } catch {
        return "error"
    }
}

function Wait-ForEC2State {
    param([string]$DesiredState, [int]$TimeoutSeconds = 300)
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        $current = Get-EC2State
        if ($current -eq $DesiredState) { return $true }
        Write-Host "    EC2: $current ... waiting for '$DesiredState' ($elapsed`s)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 10
        $elapsed += 10
    }
    return $false
}

function Wait-ForRDSState {
    param([string]$DesiredState, [int]$TimeoutSeconds = 600)
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        $current = Get-RDSState
        if ($current -eq $DesiredState) { return $true }
        Write-Host "    RDS: $current ... waiting for '$DesiredState' ($elapsed`s)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 15
        $elapsed += 15
    }
    return $false
}

# -- Main Logic --

Write-Header

# Step 1: Detect current state
Write-Host "  [1/4] Detecting current state..." -ForegroundColor Yellow
$ec2State = Get-EC2State
$rdsState = Get-RDSState

Write-Host "         EC2 ($EC2_INSTANCE_ID): " -NoNewline -ForegroundColor White
if ($ec2State -eq "running") {
    Write-Host "$ec2State" -ForegroundColor Green
} elseif ($ec2State -eq "stopped") {
    Write-Host "$ec2State" -ForegroundColor Red
} else {
    Write-Host "$ec2State" -ForegroundColor Yellow
}

Write-Host "         RDS ($RDS_INSTANCE_ID): " -NoNewline -ForegroundColor White
if ($rdsState -eq "available") {
    Write-Host "$rdsState" -ForegroundColor Green
} elseif ($rdsState -eq "stopped") {
    Write-Host "$rdsState" -ForegroundColor Red
} else {
    Write-Host "$rdsState" -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Determine action based on current state
$isRunning = ($ec2State -eq "running") -or ($rdsState -eq "available")

if ($isRunning) {
    # -- STOP all resources --
    Write-Host "  [2/4] ACTION: STOPPING all $PROJECT_NAME AWS resources..." -ForegroundColor Red
    Write-Host "         This will save costs. Resources will be offline." -ForegroundColor DarkGray
    Write-Host ""

    $confirm = Read-Host "         Type 'STOP' to confirm (or anything else to cancel)"
    if ($confirm -ne "STOP") {
        Write-Host ""
        Write-Host "  Cancelled. No changes made." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit 0
    }

    # Stop EC2 first (so k3s doesn't write to RDS while it's stopping)
    Write-Host ""
    Write-Host "  [3/4] Stopping EC2 instance..." -ForegroundColor Red
    aws ec2 stop-instances `
        --instance-ids $EC2_INSTANCE_ID `
        --region $AWS_REGION `
        --output json | Out-Null

    $ec2Ok = Wait-ForEC2State -DesiredState "stopped" -TimeoutSeconds 180
    if ($ec2Ok) {
        Write-Host "    EC2: STOPPED" -ForegroundColor Green
    } else {
        Write-Host "    EC2: Timed out waiting for stop (may still be stopping)" -ForegroundColor Yellow
    }

    # Stop RDS
    Write-Host "  [4/4] Stopping RDS instance..." -ForegroundColor Red
    aws rds stop-db-instance `
        --db-instance-identifier $RDS_INSTANCE_ID `
        --region $AWS_REGION `
        --output json | Out-Null

    $rdsOk = Wait-ForRDSState -DesiredState "stopped" -TimeoutSeconds 600
    if ($rdsOk) {
        Write-Host "    RDS: STOPPED" -ForegroundColor Green
    } else {
        Write-Host "    RDS: Still stopping (RDS can take 5-10 min, check AWS Console)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  ======================================================" -ForegroundColor Red
    Write-Host "  |   ALL RESOURCES STOPPED -- Costs are now minimized  |" -ForegroundColor Red
    Write-Host "  |   Double-click this script again to restart         |" -ForegroundColor Red
    Write-Host "  ======================================================" -ForegroundColor Red

} else {
    # -- START all resources --
    Write-Host "  [2/4] ACTION: STARTING all $PROJECT_NAME AWS resources..." -ForegroundColor Green
    Write-Host "         Resources will come online. Billing resumes." -ForegroundColor DarkGray
    Write-Host ""

    $confirm = Read-Host "         Type 'START' to confirm (or anything else to cancel)"
    if ($confirm -ne "START") {
        Write-Host ""
        Write-Host "  Cancelled. No changes made." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit 0
    }

    # Start RDS first (so it's ready when k3s pods start connecting)
    Write-Host ""
    Write-Host "  [3/4] Starting RDS instance..." -ForegroundColor Green
    aws rds start-db-instance `
        --db-instance-identifier $RDS_INSTANCE_ID `
        --region $AWS_REGION `
        --output json | Out-Null

    $rdsOk = Wait-ForRDSState -DesiredState "available" -TimeoutSeconds 600
    if ($rdsOk) {
        Write-Host "    RDS: AVAILABLE" -ForegroundColor Green
    } else {
        Write-Host "    RDS: Still starting (RDS can take 5-10 min)" -ForegroundColor Yellow
    }

    # Start EC2
    Write-Host "  [4/4] Starting EC2 instance..." -ForegroundColor Green
    aws ec2 start-instances `
        --instance-ids $EC2_INSTANCE_ID `
        --region $AWS_REGION `
        --output json | Out-Null

    $ec2Ok = Wait-ForEC2State -DesiredState "running" -TimeoutSeconds 180
    if ($ec2Ok) {
        Write-Host "    EC2: RUNNING" -ForegroundColor Green
    } else {
        Write-Host "    EC2: Timed out waiting for start" -ForegroundColor Yellow
    }

    # Get new public IP (it changes on stop/start for non-EIP instances)
    Start-Sleep -Seconds 5
    $newIp = aws ec2 describe-instances `
        --instance-ids $EC2_INSTANCE_ID `
        --region $AWS_REGION `
        --query "Reservations[0].Instances[0].PublicIpAddress" `
        --output text

    Write-Host ""
    Write-Host "  ======================================================" -ForegroundColor Green
    Write-Host "  |   ALL RESOURCES STARTED -- System is coming online  |" -ForegroundColor Green
    Write-Host "  |                                                      |" -ForegroundColor Green
    Write-Host "  |   New EC2 Public IP: $newIp" -ForegroundColor Green
    Write-Host "  |                                                      |" -ForegroundColor Green
    Write-Host "  |   NOTE: k3s + ArgoCD may take 2-5 min to fully      |" -ForegroundColor Green
    Write-Host "  |   stabilize after startup.                           |" -ForegroundColor Green
    Write-Host "  |                                                      |" -ForegroundColor Green
    Write-Host "  |   WARNING: If IP changed, update:                    |" -ForegroundColor Yellow
    Write-Host "  |     - SSH config (~/.ssh/config)                     |" -ForegroundColor Yellow
    Write-Host "  |     - DNS records (if applicable)                    |" -ForegroundColor Yellow
    Write-Host "  |     - Security group inbound rules (if needed)       |" -ForegroundColor Yellow
    Write-Host "  |                                                      |" -ForegroundColor Green
    Write-Host "  |   Double-click this script again to stop             |" -ForegroundColor Green
    Write-Host "  ======================================================" -ForegroundColor Green
}

Write-Host ""
Read-Host "  Press Enter to exit"
