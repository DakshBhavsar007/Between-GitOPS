<#
.SYNOPSIS
    Between-GitOps AWS Cost Management Toggle
    Production Infrastructure Orchestrator (EC2, RDS, Route 53, k3s, HTTPS)

.DESCRIPTION
    Double-click Between-AWS-Toggle.bat to run this script.
    It automatically determines whether the Between infrastructure is running or stopped:

    - When RUNNING:
        1. Confirms intent with user (Y/N).
        2. Safely stops EC2 instance (k3s cluster and workloads).
        3. Safely stops RDS instance (PostgreSQL database).
        4. Verifies both resources reach 'stopped' state.
        5. Displays cost-saving summary and storage charge caveats.

    - When STOPPED:
        1. Starts RDS PostgreSQL FIRST and waits until 'available'.
        2. Starts EC2 instance and waits until 'running'.
        3. Detects whether an Elastic IP is attached.
        4. Automatically discovers new EC2 public IPv4.
        5. Compares Route 53 A-record with current EC2 IP.
        6. Automatically updates Route 53 A-record if IP has changed.
        7. Waits for k3s and container workloads to initialize.
        8. Verifies public production HTTPS endpoints (https://between.dakshaws.sryze.cc).
        9. Displays final production URL and status summary.

.NOTES
    Region: ap-south-1
    Domain: between.dakshaws.sryze.cc
    Requires: AWS CLI configured with active credentials
#>

# -- Configuration --
$AWS_REGION         = "ap-south-1"
$EC2_INSTANCE_ID    = "i-0b49f1e35eeca2dc2"
$RDS_INSTANCE_ID    = "between-prod-db"
$DOMAIN_NAME        = "between.dakshaws.sryze.cc"
$HOSTED_ZONE_NAME   = "dakshaws.sryze.cc"
$HOSTED_ZONE_ID     = "Z00461951PY8ZI656LW0V"
$PROJECT_NAME       = "Between (Vishleshan) Production"

# -- Formatting Helpers --

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " BETWEEN AWS COST MANAGEMENT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "AWS Region: $AWS_REGION" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "EC2:" -ForegroundColor DarkGray
    Write-Host "$EC2_INSTANCE_ID" -ForegroundColor White
    Write-Host ""
    Write-Host "RDS:" -ForegroundColor DarkGray
    Write-Host "$RDS_INSTANCE_ID" -ForegroundColor White
    Write-Host ""
    Write-Host "Domain:" -ForegroundColor DarkGray
    Write-Host "$DOMAIN_NAME" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# -- AWS CLI & Pre-flight Checks --

function Test-Prerequisites {
    Write-Host "Verifying AWS CLI & credentials..." -NoNewline -ForegroundColor White
    $awsCmd = Get-Command aws -ErrorAction SilentlyContinue
    if (-not $awsCmd) {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "AWS CLI is not installed or not in PATH." -ForegroundColor Red
        Write-Host "Install AWS CLI and run 'aws configure' first." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }

    $identity = aws sts get-caller-identity --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "AWS authentication is unavailable." -ForegroundColor Red
        Write-Host "Run aws configure or configure your AWS profile first." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }

    Write-Host " OK" -ForegroundColor Green
    Write-Host ""
    return $true
}

# -- State Query Functions --

function Get-EC2State {
    try {
        $state = aws ec2 describe-instances `
            --instance-ids $EC2_INSTANCE_ID `
            --region $AWS_REGION `
            --query "Reservations[0].Instances[0].State.Name" `
            --output text 2>&1
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($state)) { return "unknown" }
        return $state.Trim()
    } catch {
        return "error"
    }
}

function Get-EC2PublicIp {
    try {
        $ip = aws ec2 describe-instances `
            --instance-ids $EC2_INSTANCE_ID `
            --region $AWS_REGION `
            --query "Reservations[0].Instances[0].PublicIpAddress" `
            --output text 2>&1
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ip) -or $ip -eq "None") { return $null }
        return $ip.Trim()
    } catch {
        return $null
    }
}

function Get-EC2PrivateIp {
    try {
        $ip = aws ec2 describe-instances `
            --instance-ids $EC2_INSTANCE_ID `
            --region $AWS_REGION `
            --query "Reservations[0].Instances[0].PrivateIpAddress" `
            --output text 2>&1
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ip) -or $ip -eq "None") { return $null }
        return $ip.Trim()
    } catch {
        return $null
    }
}

function Get-RDSState {
    try {
        $state = aws rds describe-db-instances `
            --db-instance-identifier $RDS_INSTANCE_ID `
            --region $AWS_REGION `
            --query "DBInstances[0].DBInstanceStatus" `
            --output text 2>&1
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($state)) { return "unknown" }
        return $state.Trim()
    } catch {
        return "error"
    }
}

function Check-ElasticIpAttached {
    try {
        $eips = aws ec2 describe-addresses `
            --filters "Name=instance-id,Values=$EC2_INSTANCE_ID" `
            --region $AWS_REGION `
            --query "Addresses[*].PublicIp" `
            --output text 2>&1
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($eips) -and $eips -ne "None") {
            return $eips.Trim()
        }
        return $null
    } catch {
        return $null
    }
}

# -- Route 53 Management Functions --

function Get-Route53ArecordIp {
    try {
        $dnsIp = aws route53 list-resource-record-sets `
            --hosted-zone-id $HOSTED_ZONE_ID `
            --query "ResourceRecordSets[?Name=='$DOMAIN_NAME.' && Type=='A'].ResourceRecords[0].Value" `
            --output text 2>&1
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($dnsIp) -and $dnsIp -ne "None") {
            return $dnsIp.Trim()
        }
        return $null
    } catch {
        return $null
    }
}

function Update-Route53Arecord {
    param([string]$NewIp)
    try {
        $changeBatch = @"
{
  "Comment": "Auto-updated by Between-AWS-Toggle script",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$DOMAIN_NAME.",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$NewIp"
          }
        ]
      }
    }
  ]
}
"@
        $tempJson = Join-Path $env:TEMP "route53-change-$((Get-Date).Ticks).json"
        Set-Content -Path $tempJson -Value $changeBatch -Encoding ASCII

        $res = aws route53 change-resource-record-sets `
            --hosted-zone-id $HOSTED_ZONE_ID `
            --change-batch "file://$tempJson" 2>&1

        Remove-Item -Path $tempJson -Force -ErrorAction SilentlyContinue

        if ($LASTEXITCODE -eq 0) {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

# -- Wait & Polling Helpers --

function Wait-ForEC2State {
    param([string]$DesiredState, [int]$TimeoutSeconds = 300)
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        $current = Get-EC2State
        Write-Host "EC2 status: $current..." -ForegroundColor DarkGray
        if ($current -eq $DesiredState) { 
            Write-Host "EC2 status: $DesiredState" -ForegroundColor Green
            return $true 
        }
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
        Write-Host "RDS status: $current..." -ForegroundColor DarkGray
        if ($current -eq $DesiredState) { 
            Write-Host "RDS status: $DesiredState" -ForegroundColor Green
            return $true 
        }
        Start-Sleep -Seconds 15
        $elapsed += 15
    }
    return $false
}

# -- HTTP / HTTPS Verification Helper --

function Test-HttpEndpoint {
    param(
        [string]$Url,
        [int]$MaxAttempts = 8,
        [int]$IntervalSeconds = 5
    )
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            $req = [System.Net.WebRequest]::Create($Url)
            $req.Timeout = 7000
            $req.Method = "GET"
            $resp = $req.GetResponse()
            $httpCode = [int]$resp.StatusCode
            $resp.Close()

            if ($httpCode -eq 200) {
                return 200
            }
        } catch [System.Net.WebException] {
            if ($_.Exception.Response) {
                $code = [int]$_.Exception.Response.StatusCode
                if ($code -eq 200) { return 200 }
            }
        } catch {
            # initializing
        }

        if ($attempt -lt $MaxAttempts) {
            Start-Sleep -Seconds $IntervalSeconds
        }
        $attempt++
    }
    return 0
}

# ==============================================================================
# MAIN EXECUTION FLOW
# ==============================================================================

Write-Header

if (-not (Test-Prerequisites)) {
    Read-Host "Press Enter to exit..."
    exit 1
}

$ec2State = Get-EC2State
$rdsState = Get-RDSState

# Check for transitional states
$transitionalEc2 = @("pending", "stopping", "shutting-down")
$transitionalRds = @("starting", "stopping", "modifying", "backing-up")

if ($transitionalEc2 -contains $ec2State -or $transitionalRds -contains $rdsState) {
    Write-Host "Detected State:" -ForegroundColor Yellow
    Write-Host "TRANSITIONAL" -ForegroundColor Yellow
    Write-Host ""
    if ($transitionalRds -contains $rdsState) {
        Write-Host "RDS is currently $rdsState." -ForegroundColor Yellow
        Write-Host "Please wait until the operation completes." -ForegroundColor Yellow
    }
    if ($transitionalEc2 -contains $ec2State) {
        Write-Host "EC2 is currently $ec2State." -ForegroundColor Yellow
        Write-Host "Please wait until the operation completes." -ForegroundColor Yellow
    }
    Write-Host ""
    Read-Host "Press Enter to exit..."
    exit 0
}

# State detection
$isCurrentlyRunning = ($ec2State -eq "running") -or ($rdsState -eq "available")

if ($isCurrentlyRunning) {
    Write-Host "Detected State:" -ForegroundColor Yellow
    Write-Host "RUNNING" -ForegroundColor Green
    Write-Host ""
    Write-Host "Action:" -ForegroundColor Yellow
    Write-Host "STOPPING INFRASTRUCTURE..." -ForegroundColor Red
} else {
    Write-Host "Detected State:" -ForegroundColor Yellow
    Write-Host "STOPPED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Action:" -ForegroundColor Yellow
    Write-Host "STARTING INFRASTRUCTURE..." -ForegroundColor Green
}
Write-Host ""

# ==============================================================================
# STOP MODE
# ==============================================================================
if ($isCurrentlyRunning) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " BETWEEN AWS COST MANAGEMENT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current State:" -ForegroundColor Yellow
    Write-Host "RUNNING" -ForegroundColor Green
    Write-Host ""
    Write-Host "The following AWS resources are consuming compute/database cost:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "EC2: $EC2_INSTANCE_ID" -ForegroundColor White
    Write-Host "RDS: $RDS_INSTANCE_ID" -ForegroundColor White
    Write-Host ""
    Write-Host "Stopping Between production infrastructure..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $confirm = Read-Host "Are you sure you want to stop Between production infrastructure? (Y/N)"
    if ($confirm -notmatch '^(y|yes)$') {
        Write-Host ""
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit..."
        exit 0
    }

    Write-Host ""
    # Stop EC2 first (prevents application writes while RDS shuts down)
    Write-Host "Stopping EC2 ($EC2_INSTANCE_ID)..." -ForegroundColor Yellow
    aws ec2 stop-instances --instance-ids $EC2_INSTANCE_ID --region $AWS_REGION --output json | Out-Null
    $ec2StopOk = Wait-ForEC2State -DesiredState "stopped" -TimeoutSeconds 300
    if (-not $ec2StopOk) {
        Write-Host "WARNING: EC2 stop timed out. Check AWS console." -ForegroundColor Yellow
    }

    Write-Host ""
    # Stop RDS
    Write-Host "Stopping RDS ($RDS_INSTANCE_ID)..." -ForegroundColor Yellow
    if ($rdsState -ne "stopped") {
        aws rds stop-db-instance --db-instance-identifier $RDS_INSTANCE_ID --region $AWS_REGION --output json | Out-Null
        $rdsStopOk = Wait-ForRDSState -DesiredState "stopped" -TimeoutSeconds 600
        if (-not $rdsStopOk) {
            Write-Host "WARNING: RDS stop timed out or still stopping." -ForegroundColor Yellow
        }
    } else {
        Write-Host "RDS was already stopped." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " BETWEEN AWS INFRASTRUCTURE STOPPED" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "EC2: STOPPED" -ForegroundColor White
    Write-Host "RDS: STOPPED" -ForegroundColor White
    Write-Host ""
    Write-Host "k3s / ArgoCD / Traefik / Backend / Frontend /" -ForegroundColor DarkGray
    Write-Host "Celery / Redis are offline because EC2 is stopped." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "RDS PostgreSQL is stopped." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Cost-saving mode: ACTIVE" -ForegroundColor Green
    Write-Host ""
    Write-Host "NOTE:" -ForegroundColor Cyan
    Write-Host "Route 53 remains active because DNS itself cannot be" -ForegroundColor DarkGray
    Write-Host "`"stopped`" like EC2/RDS." -ForegroundColor DarkGray
    Write-Host "Persistent EBS/RDS storage may continue to incur storage" -ForegroundColor DarkGray
    Write-Host "charges even while compute is stopped." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "RDS 7-Day Auto-Restart Notice:" -ForegroundColor Cyan
    Write-Host "AWS automatically restarts stopped RDS databases after 7 consecutive days" -ForegroundColor DarkGray
    Write-Host "if not started manually. Periodically verify RDS state." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "This reduces the ongoing compute/database runtime costs for the Between environment." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan

# ==============================================================================
# START MODE
# ==============================================================================
} else {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " BETWEEN AWS COST MANAGEMENT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current State:" -ForegroundColor Yellow
    Write-Host "STOPPED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Starting Between production infrastructure..." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Start RDS first
    Write-Host "Starting RDS ($RDS_INSTANCE_ID)..." -ForegroundColor Yellow
    if ($rdsState -ne "available") {
        aws rds start-db-instance --db-instance-identifier $RDS_INSTANCE_ID --region $AWS_REGION --output json | Out-Null
        $rdsStartOk = Wait-ForRDSState -DesiredState "available" -TimeoutSeconds 600

        if (-not $rdsStartOk) {
            Write-Host ""
            Write-Host "RDS startup failed." -ForegroundColor Red
            Write-Host "EC2 startup will not continue." -ForegroundColor Red
            Write-Host "Check AWS RDS status." -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Press Enter to exit..."
            exit 1
        }
    } else {
        Write-Host "RDS status: available" -ForegroundColor Green
    }

    # Step 2: Start EC2
    Write-Host ""
    Write-Host "Starting EC2 ($EC2_INSTANCE_ID)..." -ForegroundColor Yellow
    if ($ec2State -ne "running") {
        aws ec2 start-instances --instance-ids $EC2_INSTANCE_ID --region $AWS_REGION --output json | Out-Null
        $ec2StartOk = Wait-ForEC2State -DesiredState "running" -TimeoutSeconds 300
        if (-not $ec2StartOk) {
            Write-Host ""
            Write-Host "EC2 startup failed." -ForegroundColor Red
            Write-Host "Check AWS EC2 status." -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Press Enter to exit..."
            exit 1
        }
    } else {
        Write-Host "EC2 status: running" -ForegroundColor Green
    }

    # Step 3: Detect Public IPv4 & Private IPv4
    Start-Sleep -Seconds 3
    $newEc2Ip = Get-EC2PublicIp
    $privateEc2Ip = Get-EC2PrivateIp

    Write-Host ""
    Write-Host "EC2 Network Configuration:" -ForegroundColor Cyan
    Write-Host "Public IPv4  : $newEc2Ip" -ForegroundColor White
    Write-Host "Private IPv4 : $privateEc2Ip" -ForegroundColor White
    Write-Host ""

    # Step 4: Elastic IP Detection & Route 53 Automatic Update
    $attachedEip = Check-ElasticIpAttached

    if ($attachedEip) {
        Write-Host "Elastic IP detected." -ForegroundColor Green
        Write-Host "DNS update should normally not be necessary." -ForegroundColor DarkGray
    } else {
        Write-Host "No Elastic IP detected." -ForegroundColor Yellow
        Write-Host "EC2 public IP may change after restart." -ForegroundColor DarkGray
        Write-Host "Route 53 A record will be automatically updated." -ForegroundColor DarkGray
        Write-Host ""

        if (-not [string]::IsNullOrWhiteSpace($newEc2Ip)) {
            $currentDnsIp = Get-Route53ArecordIp

            if ($currentDnsIp -ne $newEc2Ip) {
                Write-Host "Route 53 DNS Update" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Old IP: $currentDnsIp" -ForegroundColor DarkGray
                Write-Host "New IP: $newEc2Ip" -ForegroundColor Cyan
                Write-Host ""

                $dnsUpdated = Update-Route53Arecord -NewIp $newEc2Ip
                if ($dnsUpdated) {
                    Write-Host "DNS record updated successfully." -ForegroundColor Green
                } else {
                    Write-Host ""
                    Write-Host "WARNING:" -ForegroundColor Red
                    Write-Host "EC2 started successfully but Route 53 update failed." -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Current EC2 IP:" -ForegroundColor Yellow
                    Write-Host "$newEc2Ip" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Current DNS IP:" -ForegroundColor Yellow
                    Write-Host "$currentDnsIp" -ForegroundColor Yellow
                }
            } else {
                Write-Host "Route 53 A record is already synchronized ($newEc2Ip)." -ForegroundColor Green
            }
        } else {
            Write-Host "WARNING: Could not detect EC2 public IPv4 address." -ForegroundColor Yellow
        }
    }

    # Step 5: Wait for k3s cluster readiness
    Write-Host ""
    Write-Host "Waiting for k3s & container workloads to initialize..." -ForegroundColor Yellow
    Write-Host "Allowing 35 seconds for Traefik, Frontend, Backend, Redis, and Celery to bind..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 35

    # Step 6: Verify Production URLs
    Write-Host ""
    Write-Host "Verifying production endpoints..." -ForegroundColor Cyan

    $endpoint1 = "https://$DOMAIN_NAME/"
    $endpoint2 = "https://$DOMAIN_NAME/healthz"
    $endpoint3 = "https://$DOMAIN_NAME/api/v1/health"

    Write-Host "Check:" -ForegroundColor DarkGray
    Write-Host "$endpoint1" -ForegroundColor White
    $code1 = Test-HttpEndpoint -Url $endpoint1 -MaxAttempts 8 -IntervalSeconds 6

    Write-Host "Then:" -ForegroundColor DarkGray
    Write-Host "$endpoint2" -ForegroundColor White
    $code2 = Test-HttpEndpoint -Url $endpoint2 -MaxAttempts 5 -IntervalSeconds 5

    Write-Host "Then:" -ForegroundColor DarkGray
    Write-Host "$endpoint3" -ForegroundColor White
    $code3 = Test-HttpEndpoint -Url $endpoint3 -MaxAttempts 5 -IntervalSeconds 5

    Write-Host ""
    if ($code1 -eq 200 -and $code2 -eq 200 -and $code3 -eq 200) {
        Write-Host "HTTPS verification: ALL PASS (HTTP 200 OK)" -ForegroundColor Green
        Write-Host ""
        Write-Host "Production URLs:" -ForegroundColor Cyan
        Write-Host "- Frontend SPA : $endpoint1 (HTTP 200)" -ForegroundColor Green
        Write-Host "- Edge Health  : $endpoint2 (HTTP 200)" -ForegroundColor Green
        Write-Host "- API / DB     : $endpoint3 (HTTP 200)" -ForegroundColor Green
    } else {
        Write-Host "WARNING:" -ForegroundColor Yellow
        Write-Host "Infrastructure started, but HTTPS verification failed." -ForegroundColor Yellow
        Write-Host "- $endpoint1 -> HTTP $code1" -ForegroundColor DarkGray
        Write-Host "- $endpoint2 -> HTTP $code2" -ForegroundColor DarkGray
        Write-Host "- $endpoint3 -> HTTP $code3" -ForegroundColor DarkGray
        Write-Host "Traefik or pods may need an additional 1-2 minutes to stabilize." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " OPERATION COMPLETED" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit..."
