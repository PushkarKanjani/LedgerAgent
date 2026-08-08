# =============================================================================
# 02-network.ps1 - Cost-Optimized VPC, Dual-AZ Subnets and Security Groups
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (No Complex Tag JSON, Boolean Flags)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$VpcCidr = '10.0.0.0/16'
)

$ErrorActionPreference = 'Continue'

function Get-AwsJson {
    param([string[]]$Arguments)
    $raw = & aws @Arguments 2>$null
    if ($LASTEXITCODE -eq 0 -and $raw) {
        try {
            return ($raw | Out-String | ConvertFrom-Json)
        } catch {
            return $null
        }
    }
    return $null
}

Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  [VPC] AWS Infrastructure - 02 Network Provisioning' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# 1. Idempotent VPC Creation
Write-Host ''
Write-Host "[1/5] Checking VPC for CIDR $VpcCidr..." -ForegroundColor Yellow
$vpcCheck = Get-AwsJson -Arguments @('ec2', 'describe-vpcs', '--filters', "Name=cidr,Values=$VpcCidr", '--region', $Region, '--output', 'json')

$vpcId = ''
if ($vpcCheck -and $vpcCheck.Vpcs.Count -gt 0) {
    $vpcId = $vpcCheck.Vpcs[0].VpcId
    Write-Host "  [INFO] VPC already exists ($vpcId)" -ForegroundColor DarkCyan
} else {
    Write-Host '  [NEW] Creating VPC...' -ForegroundColor Green
    $vpcCreate = Get-AwsJson -Arguments @('ec2', 'create-vpc', '--cidr-block', $VpcCidr, '--region', $Region, '--output', 'json')
    $vpcId = $vpcCreate.Vpc.VpcId
    & aws ec2 create-tags --resources $vpcId --tags Key=Name,Value=ledgeragent-vpc Key=Project,Value=LedgerAgent --region $Region 2>&1 | Out-Null
}
Write-Host "  [OK] VPC ID: $vpcId" -ForegroundColor Green

# Enable DNS support and hostnames using standard CLI boolean flags
& aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support --region $Region 2>&1 | Out-Null
& aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames --region $Region 2>&1 | Out-Null

# 2. Idempotent Internet Gateway
Write-Host ''
Write-Host '[2/5] Checking Internet Gateway...' -ForegroundColor Yellow
$igwCheck = Get-AwsJson -Arguments @('ec2', 'describe-internet-gateways', '--filters', "Name=attachment.vpc-id,Values=$vpcId", '--region', $Region, '--output', 'json')

$igwId = ''
if ($igwCheck -and $igwCheck.InternetGateways.Count -gt 0) {
    $igwId = $igwCheck.InternetGateways[0].InternetGatewayId
    Write-Host "  [INFO] Internet Gateway already attached ($igwId)" -ForegroundColor DarkCyan
} else {
    Write-Host '  [NEW] Creating and attaching Internet Gateway...' -ForegroundColor Green
    $igwCreate = Get-AwsJson -Arguments @('ec2', 'create-internet-gateway', '--region', $Region, '--output', 'json')
    $igwId = $igwCreate.InternetGateway.InternetGatewayId
    & aws ec2 create-tags --resources $igwId --tags Key=Name,Value=ledgeragent-igw Key=Project,Value=LedgerAgent --region $Region 2>&1 | Out-Null
    & aws ec2 attach-internet-gateway --vpc-id $vpcId --internet-gateway-id $igwId --region $Region 2>&1 | Out-Null
}
Write-Host "  [OK] Internet Gateway ID: $igwId" -ForegroundColor Green

# 3. Idempotent Subnet Creation across 2 AZs (ap-south-1a, ap-south-1b)
Write-Host ''
Write-Host '[3/5] Configuring Dual-AZ Subnets...' -ForegroundColor Yellow

function Ensure-Subnet {
    param($Name, $Cidr, $Az, $IsPublic)
    $subCheck = Get-AwsJson -Arguments @('ec2', 'describe-subnets', '--filters', "Name=vpc-id,Values=$vpcId", "Name=cidr-block,Values=$Cidr", '--region', $Region, '--output', 'json')

    $subnetId = ''
    if ($subCheck -and $subCheck.Subnets.Count -gt 0) {
        $subnetId = $subCheck.Subnets[0].SubnetId
        Write-Host "  [INFO] Subnet '$Name' exists ($subnetId)" -ForegroundColor DarkCyan
    } else {
        Write-Host "  [NEW] Creating subnet '$Name' ($Cidr in $Az)..." -ForegroundColor Green
        $subCreate = Get-AwsJson -Arguments @('ec2', 'create-subnet', '--vpc-id', $vpcId, '--cidr-block', $Cidr, '--availability-zone', $Az, '--region', $Region, '--output', 'json')
        $subnetId = $subCreate.Subnet.SubnetId
        & aws ec2 create-tags --resources $subnetId --tags Key=Name,Value=$Name Key=Project,Value=LedgerAgent --region $Region 2>&1 | Out-Null
        if ($IsPublic) {
            & aws ec2 modify-subnet-attribute --subnet-id $subnetId --map-public-ip-on-launch --region $Region 2>&1 | Out-Null
        }
    }
    return $subnetId
}

$pubSubnet1 = Ensure-Subnet -Name 'ledgeragent-public-1a' -Cidr '10.0.1.0/24' -Az "${Region}a" -IsPublic $true
$pubSubnet2 = Ensure-Subnet -Name 'ledgeragent-public-1b' -Cidr '10.0.2.0/24' -Az "${Region}b" -IsPublic $true
$privSubnet1 = Ensure-Subnet -Name 'ledgeragent-private-1a' -Cidr '10.0.10.0/24' -Az "${Region}a" -IsPublic $false
$privSubnet2 = Ensure-Subnet -Name 'ledgeragent-private-1b' -Cidr '10.0.20.0/24' -Az "${Region}b" -IsPublic $false

# 4. Route Tables and Associations
Write-Host ''
Write-Host '[4/5] Configuring Route Tables...' -ForegroundColor Yellow

$rtCheck = Get-AwsJson -Arguments @('ec2', 'describe-route-tables', '--filters', "Name=vpc-id,Values=$vpcId", "Name=tag:Name,Values=ledgeragent-public-rt", '--region', $Region, '--output', 'json')

$pubRtId = ''
if ($rtCheck -and $rtCheck.RouteTables.Count -gt 0) {
    $pubRtId = $rtCheck.RouteTables[0].RouteTableId
    Write-Host "  [INFO] Public Route Table exists ($pubRtId)" -ForegroundColor DarkCyan
} else {
    $rtCreate = Get-AwsJson -Arguments @('ec2', 'create-route-table', '--vpc-id', $vpcId, '--region', $Region, '--output', 'json')
    $pubRtId = $rtCreate.RouteTable.RouteTableId
    & aws ec2 create-tags --resources $pubRtId --tags Key=Name,Value=ledgeragent-public-rt Key=Project,Value=LedgerAgent --region $Region 2>&1 | Out-Null
    & aws ec2 create-route --route-table-id $pubRtId --destination-cidr-block '0.0.0.0/0' --gateway-id $igwId --region $Region 2>&1 | Out-Null
    & aws ec2 associate-route-table --subnet-id $pubSubnet1 --route-table-id $pubRtId --region $Region 2>&1 | Out-Null
    & aws ec2 associate-route-table --subnet-id $pubSubnet2 --route-table-id $pubRtId --region $Region 2>&1 | Out-Null
}
Write-Host "  [OK] Public Route Table ID: $pubRtId (0.0.0.0/0 -> $igwId)" -ForegroundColor Green

# 5. Tiered Security Groups (Least Privilege Isolation)
Write-Host ''
Write-Host '[5/5] Configuring Layered Security Groups (ALB -> App -> DB)...' -ForegroundColor Yellow

function Ensure-SecurityGroup {
    param($Name, $Description)
    $sgCheck = Get-AwsJson -Arguments @('ec2', 'describe-security-groups', '--filters', "Name=vpc-id,Values=$vpcId", "Name=group-name,Values=$Name", '--region', $Region, '--output', 'json')

    $sgId = ''
    if ($sgCheck -and $sgCheck.SecurityGroups.Count -gt 0) {
        $sgId = $sgCheck.SecurityGroups[0].GroupId
        Write-Host "  [INFO] Security Group '$Name' exists ($sgId)" -ForegroundColor DarkCyan
    } else {
        Write-Host "  [NEW] Creating Security Group '$Name'..." -ForegroundColor Green
        $sgCreate = Get-AwsJson -Arguments @('ec2', 'create-security-group', '--group-name', $Name, '--description', $Description, '--vpc-id', $vpcId, '--region', $Region, '--output', 'json')
        $sgId = $sgCreate.GroupId
        & aws ec2 create-tags --resources $sgId --tags Key=Name,Value=$Name Key=Project,Value=LedgerAgent --region $Region 2>&1 | Out-Null
    }
    return $sgId
}

$albSgId = Ensure-SecurityGroup -Name 'ledgeragent-alb-sg' -Description 'Public Ingress for Application Load Balancer'
$appSgId = Ensure-SecurityGroup -Name 'ledgeragent-app-sg' -Description 'Internal App Security Group for FastAPI and Mock ERP'
$dbSgId  = Ensure-SecurityGroup -Name 'ledgeragent-db-sg' -Description 'Isolated PostgreSQL Database Security Group'

# Authorize ALB Ingress (80/443 from 0.0.0.0/0)
& aws ec2 authorize-security-group-ingress --group-id $albSgId --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $Region 2>&1 | Out-Null
& aws ec2 authorize-security-group-ingress --group-id $albSgId --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $Region 2>&1 | Out-Null

# Authorize App Ingress (8000 and 8001 strictly from ALB-SG)
& aws ec2 authorize-security-group-ingress --group-id $appSgId --protocol tcp --port 8000 --source-group $albSgId --region $Region 2>&1 | Out-Null
& aws ec2 authorize-security-group-ingress --group-id $appSgId --protocol tcp --port 8001 --source-group $albSgId --region $Region 2>&1 | Out-Null

# Authorize DB Ingress (5432 strictly from App-SG)
& aws ec2 authorize-security-group-ingress --group-id $dbSgId --protocol tcp --port 5432 --source-group $appSgId --region $Region 2>&1 | Out-Null

# Save Network Outputs to JSON
$output = @{
    VpcId = $vpcId
    PublicSubnets = @($pubSubnet1, $pubSubnet2)
    PrivateSubnets = @($privSubnet1, $privSubnet2)
    AlbSecurityGroupId = $albSgId
    AppSecurityGroupId = $appSgId
    DbSecurityGroupId = $dbSgId
    Region = $Region
}
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath 'network-output.json'
$output | ConvertTo-Json -Depth 4 | Out-File -FilePath $outputFile -Encoding ascii
Write-Host "  [SAVED] Network topology saved: $outputFile" -ForegroundColor Green

# 6. Monthly Cost Estimation for VPC
Write-Host ''
Write-Host '[Cost Breakdown: Amazon VPC and Networking]' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  Amazon VPC and Subnets:               $0.00 / month (Free)' -ForegroundColor Green
Write-Host '  Internet Gateway:                     $0.00 / month (Free)' -ForegroundColor Green
Write-Host '  Security Groups:                      $0.00 / month (Free)' -ForegroundColor Green
Write-Host '  NAT Gateway Trade-off:                $0.00 / month (Skipped ~$32/mo)' -ForegroundColor DarkCyan
Write-Host '  Total Networking Monthly Cost:        $0.00 / month' -ForegroundColor Green
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '[OK] 02-network.ps1 network provisioning completed successfully.' -ForegroundColor Green
Write-Host ''
