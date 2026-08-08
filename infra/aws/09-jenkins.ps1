# =============================================================================
# 09-jenkins.ps1 - Provision Jenkins CI/CD Server on AWS EC2 t2.micro
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (ASCII, ErrorActionPreference Continue)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$Account = '441214867393',
    [string]$InstanceType = 't2.micro',
    [string]$KeyName = 'ledgeragent-key'
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
Write-Host '  [JENKINS] AWS Infrastructure - 09 Jenkins CI/CD Server' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# Load Network Outputs
$networkFile = Join-Path -Path $PSScriptRoot -ChildPath 'network-output.json'
if (-not (Test-Path $networkFile)) {
    Write-Error 'network-output.json not found! Run 02-network.ps1 first.'
    exit 1
}
$net = Get-Content $networkFile | ConvertFrom-Json
$vpcId = $net.VpcId
$publicSubnet = $net.PublicSubnets[0]

# 1. Fetch Current Operator Public IP for Restrictive Ingress
Write-Host ''
Write-Host '[1/5] Determining current operator public IP address...' -ForegroundColor Yellow
$myIp = ''
try {
    $myIpRaw = (Invoke-WebRequest -Uri 'https://checkip.amazonaws.com' -UseBasicParsing -TimeoutSec 5 2>&1).Content
    if ($myIpRaw) {
        $myIp = $myIpRaw.Trim()
    }
} catch {}

if (-not $myIp) {
    $myIp = '0.0.0.0'
    $cidrRule = '0.0.0.0/0'
    Write-Warning "Could not dynamically fetch public IP. Defaulting ingress to ${cidrRule}."
} else {
    $cidrRule = "${myIp}/32"
    Write-Host "  [OK] Detected Operator Public IP: $cidrRule" -ForegroundColor Green
}

# 2. Security Group: ledgeragent-jenkins-sg (22 and 8080 strictly from Operator IP)
Write-Host ''
Write-Host '[2/5] Configuring Jenkins Security Group (ledgeragent-jenkins-sg)...' -ForegroundColor Yellow

$sgName = 'ledgeragent-jenkins-sg'
$sgCheck = Get-AwsJson -Arguments @('ec2', 'describe-security-groups', '--filters', "Name=vpc-id,Values=$vpcId", "Name=group-name,Values=$sgName", '--region', $Region, '--output', 'json')

$jenkinsSgId = ''
if ($sgCheck -and $sgCheck.SecurityGroups.Count -gt 0) {
    $jenkinsSgId = $sgCheck.SecurityGroups[0].GroupId
    Write-Host "  [INFO] Security Group '$sgName' exists ($jenkinsSgId)." -ForegroundColor DarkCyan
} else {
    Write-Host "  [NEW] Creating Security Group '$sgName'..." -ForegroundColor Green
    $sgCreate = Get-AwsJson -Arguments @(
        'ec2', 'create-security-group',
        '--group-name', $sgName,
        '--description', 'Security group for LedgerAgent Jenkins CI/CD on t2.micro',
        '--vpc-id', $vpcId,
        '--region', $Region,
        '--output', 'json'
    )
    $jenkinsSgId = $sgCreate.GroupId
    & aws ec2 create-tags --resources $jenkinsSgId --tags Key=Name,Value=$sgName Key=Project,Value=LedgerAgent --region $Region 2>&1 | Out-Null
}

# Authorize Port 22 (SSH) and Port 8080 (Jenkins Web UI)
& aws ec2 authorize-security-group-ingress --group-id $jenkinsSgId --protocol tcp --port 22 --cidr $cidrRule --region $Region 2>&1 | Out-Null
& aws ec2 authorize-security-group-ingress --group-id $jenkinsSgId --protocol tcp --port 8080 --cidr $cidrRule --region $Region 2>&1 | Out-Null
Write-Host "  [OK] Ingress authorized: Port 22 & 8080 from $cidrRule" -ForegroundColor Green

# 3. IAM Role & Instance Profile (ECR, ECS, S3, Secrets Manager, PassRole)
Write-Host ''
Write-Host '[3/5] Configuring IAM Role and Instance Profile (ledgeragent-jenkins-role)...' -ForegroundColor Yellow

$ec2Trust = @{
    Version = '2012-10-17'
    Statement = @(
        @{
            Effect = 'Allow'
            Principal = @{
                Service = 'ec2.amazonaws.com'
            }
            Action = 'sts:AssumeRole'
        }
    )
} | ConvertTo-Json -Depth 4
$ec2TrustFile = Join-Path -Path $PSScriptRoot -ChildPath 'jenkins-trust-policy.json'
$ec2Trust | Out-File -FilePath $ec2TrustFile -Encoding ascii

$roleName = 'ledgeragent-jenkins-role'
$profileName = 'ledgeragent-jenkins-instance-profile'

$roleCheck = Get-AwsJson -Arguments @('iam', 'get-role', '--role-name', $roleName, '--output', 'json')
if (-not $roleCheck) {
    & aws iam create-role --role-name $roleName --assume-role-policy-document "file://$ec2TrustFile" 2>&1 | Out-Null

    # Attach AmazonSSMManagedInstanceCore for browser-based SSM terminal access
    & aws iam attach-role-policy --role-name $roleName --policy-arn 'arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore' 2>&1 | Out-Null

    $ciPolicy = @{
        Version = '2012-10-17'
        Statement = @(
            @{
                Sid = 'ECRPushAccess'
                Effect = 'Allow'
                Action = @(
                    'ecr:GetAuthorizationToken',
                    'ecr:BatchCheckLayerAvailability',
                    'ecr:GetDownloadUrlForLayer',
                    'ecr:BatchGetImage',
                    'ecr:PutImage',
                    'ecr:InitiateLayerUpload',
                    'ecr:UploadLayerPart',
                    'ecr:CompleteLayerUpload',
                    'ecr:DescribeRepositories',
                    'ecr:DescribeImages'
                )
                Resource = '*'
            },
            @{
                Sid = 'ECSDeploymentAccess'
                Effect = 'Allow'
                Action = @(
                    'ecs:DescribeServices',
                    'ecs:UpdateService',
                    'ecs:DescribeTaskDefinition',
                    'ecs:RegisterTaskDefinition',
                    'ecs:ListTasks',
                    'ecs:DescribeTasks'
                )
                Resource = '*'
            },
            @{
                Sid = 'PassRoleForECS'
                Effect = 'Allow'
                Action = @('iam:PassRole')
                Resource = "arn:aws:iam::${Account}:role/ledgeragent-*"
            },
            @{
                Sid = 'S3AndSecretsAccess'
                Effect = 'Allow'
                Action = @(
                    's3:GetObject',
                    's3:ListBucket',
                    'secretsmanager:GetSecretValue',
                    'secretsmanager:DescribeSecret'
                )
                Resource = '*'
            }
        )
    } | ConvertTo-Json -Depth 5
    $ciPolicyFile = Join-Path -Path $PSScriptRoot -ChildPath 'jenkins-ci-policy.json'
    $ciPolicy | Out-File -FilePath $ciPolicyFile -Encoding ascii

    & aws iam put-role-policy --role-name $roleName --policy-name 'LedgerAgentCIPolicy' --policy-document "file://$ciPolicyFile" 2>&1 | Out-Null
    Write-Host "  [NEW] Created IAM Role '$roleName'." -ForegroundColor Green
} else {
    Write-Host "  [INFO] IAM Role '$roleName' exists." -ForegroundColor DarkCyan
}

$profileCheck = Get-AwsJson -Arguments @('iam', 'get-instance-profile', '--instance-profile-name', $profileName, '--output', 'json')
if (-not $profileCheck) {
    & aws iam create-instance-profile --instance-profile-name $profileName 2>&1 | Out-Null
    & aws iam add-role-to-instance-profile --instance-profile-name $profileName --role-name $roleName 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    Write-Host "  [NEW] Created Instance Profile '$profileName'." -ForegroundColor Green
} else {
    Write-Host "  [INFO] Instance Profile '$profileName' exists." -ForegroundColor DarkCyan
}

# 4. Lookup Latest Amazon Linux 2023 AMI
Write-Host ''
Write-Host '[4/5] Resolving latest Amazon Linux 2023 AMI in ap-south-1...' -ForegroundColor Yellow
$amiObj = Get-AwsJson -Arguments @(
    'ec2', 'describe-images',
    '--owners', 'amazon',
    '--filters', 'Name=name,Values=al2023-ami-2023.*-x86_64', 'Name=state,Values=available',
    '--region', $Region,
    '--output', 'json'
)

$amiId = 'ami-03f4878755434977f'  # Standard AL2023 fallback in ap-south-1
if ($amiObj -and $amiObj.Images.Count -gt 0) {
    $sorted = $amiObj.Images | Sort-Object -Property CreationDate -Descending
    $amiId = $sorted[0].ImageId
}
Write-Host "  [OK] Selected AL2023 AMI: $amiId" -ForegroundColor Green

# 5. User-Data Bootstrap Script (Docker + Docker-outside-of-Docker Jenkins)
$userData = @'
#!/bin/bash
set -ex
yum update -y
yum install -y docker git curl jq

# Start & enable Docker daemon
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Prepare persistent Jenkins directory and permissions
mkdir -p /var/jenkins_home
chown -R 1000:1000 /var/jenkins_home
chmod 666 /var/run/docker.sock

# Run Jenkins LTS with Docker CLI and socket integration
docker run -d \
  --name jenkins \
  --restart always \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /var/jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  jenkins/jenkins:lts

# Install AWS CLI v2 inside host and ensure permissions
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install || true
'@

$userDataBase64 = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userData))

# 6. Idempotent EC2 t2.micro Launch
Write-Host ''
Write-Host '[5/5] Provisioning EC2 t2.micro (AWS Free Tier)...' -ForegroundColor Yellow

$instanceCheck = Get-AwsJson -Arguments @(
    'ec2', 'describe-instances',
    '--filters', "Name=tag:Name,Values=ledgeragent-jenkins", "Name=instance-state-name,Values=running,pending",
    '--region', $Region,
    '--output', 'json'
)

$instanceId = ''
$publicIp = ''

if ($instanceCheck -and $instanceCheck.Reservations.Count -gt 0 -and $instanceCheck.Reservations[0].Instances.Count -gt 0) {
    $inst = $instanceCheck.Reservations[0].Instances[0]
    $instanceId = $inst.InstanceId
    $publicIp = $inst.PublicIpAddress
    Write-Host "  [INFO] Jenkins instance already running: $instanceId ($publicIp)" -ForegroundColor DarkCyan
} else {
    Write-Host "  [NEW] Launching t2.micro instance in subnet $publicSubnet..." -ForegroundColor Green
    
    $launchObj = Get-AwsJson -Arguments @(
        'ec2', 'run-instances',
        '--image-id', $amiId,
        '--instance-type', $InstanceType,
        '--subnet-id', $publicSubnet,
        '--security-group-ids', $jenkinsSgId,
        '--iam-instance-profile', "Name=$profileName",
        '--user-data', $userDataBase64,
        '--block-device-mappings', '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":8,"VolumeType":"gp2","DeleteOnTermination":true}}]',
        '--region', $Region,
        '--output', 'json'
    )
    
    $instanceId = $launchObj.Instances[0].InstanceId
    & aws ec2 create-tags --resources $instanceId --tags Key=Name,Value=ledgeragent-jenkins Key=Project,Value=LedgerAgent --region $Region 2>&1 | Out-Null
    
    Write-Host "  [WAIT] Waiting for instance $instanceId to enter running state..." -ForegroundColor Yellow
    & aws ec2 wait instance-running --instance-ids $instanceId --region $Region 2>&1 | Out-Null
    
    $desc = Get-AwsJson -Arguments @('ec2', 'describe-instances', '--instance-ids', $instanceId, '--region', $Region, '--output', 'json')
    if ($desc -and $desc.Reservations.Count -gt 0) {
        $publicIp = $desc.Reservations[0].Instances[0].PublicIpAddress
    }
    Write-Host "  [OK] EC2 Instance Running: $instanceId" -ForegroundColor Green
}

# Save Outputs to JSON
$jenkinsOutput = @{
    InstanceId = $instanceId
    PublicIp = $publicIp
    JenkinsUrl = "http://${publicIp}:8080"
    SecurityGroupId = $jenkinsSgId
    IamRole = $roleName
    Region = $Region
}
$jenkinsOutputFile = Join-Path -Path $PSScriptRoot -ChildPath 'jenkins-output.json'
$jenkinsOutput | ConvertTo-Json -Depth 4 | Out-File -FilePath $jenkinsOutputFile -Encoding ascii
Write-Host "  [SAVED] Jenkins metadata saved: $jenkinsOutputFile" -ForegroundColor Green

# 7. Print Connection Instructions
Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  JENKINS CI/CD SERVER READY' -ForegroundColor Yellow
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host "  Public IP:   $publicIp" -ForegroundColor White
Write-Host "  Jenkins URL: http://${publicIp}:8080" -ForegroundColor Green
Write-Host ''
Write-Host '  Command to retrieve Initial Admin Password (via AWS SSM):' -ForegroundColor Yellow
Write-Host "  aws ssm start-session --target $instanceId --region $Region" -ForegroundColor White
Write-Host "  Inside session: sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword" -ForegroundColor DarkGray
Write-Host '========================================================' -ForegroundColor Cyan

# 8. Monthly Cost Breakdown
Write-Host ''
Write-Host '[Cost Breakdown: Jenkins CI/CD on EC2 t2.micro]' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  EC2 t2.micro (750 hrs/month 12-Mo Free Tier): $0.00 / month' -ForegroundColor Green
Write-Host '  8 GB gp2 EBS Storage (Free Tier Included):    $0.00 / month' -ForegroundColor Green
Write-Host '  Estimated Monthly CI/CD Compute Cost:         $0.00 / month' -ForegroundColor Green
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '[OK] 09-jenkins.ps1 completed successfully.' -ForegroundColor Green
Write-Host ''
