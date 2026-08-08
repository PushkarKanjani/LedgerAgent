# =============================================================================
# 00-prereqs.ps1 - AWS CLI and Least-Privilege IAM Verification
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (No NativeCommandError, ASCII)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$ExpectedAccount = '441214867393'
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
Write-Host '  [PREREQS] AWS Infrastructure - 00 Prereqs Verification' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# 1. Verify AWS CLI Installation
Write-Host ''
Write-Host '[1/4] Checking AWS CLI installation...' -ForegroundColor Yellow
$cliVersion = & aws --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] AWS CLI detected: $cliVersion" -ForegroundColor Green
} else {
    Write-Error 'AWS CLI is not installed or not in system PATH.'
    exit 1
}

# 2. Verify Caller Identity and Account Match
Write-Host ''
Write-Host '[2/4] Verifying AWS credentials and STS identity...' -ForegroundColor Yellow
$identityJson = Get-AwsJson -Arguments @('sts', 'get-caller-identity', '--output', 'json')

if ($identityJson) {
    $activeAccount = $identityJson.Account
    $activeArn = $identityJson.Arn

    Write-Host "  [OK] Active ARN:     $activeArn" -ForegroundColor Green
    Write-Host "  [OK] Active Account: $activeAccount" -ForegroundColor Green
    Write-Host "  [OK] Target Region:  $Region" -ForegroundColor Green

    if ($activeAccount -ne $ExpectedAccount) {
        Write-Warning "Active Account ($activeAccount) does not match expected target ($ExpectedAccount)."
    }
} else {
    Write-Error 'Failed to retrieve STS caller identity. Configure AWS CLI with credentials.'
    exit 1
}

# 3. Generate Least-Privilege IAM Policy for CI/CD Deployment
Write-Host ''
Write-Host '[3/4] Generating least-privilege IAM policy (ledgeragent-ci-policy.json)...' -ForegroundColor Yellow

$policyObj = @{
    Version = '2012-10-17'
    Statement = @(
        @{
            Sid = 'ECRRepositoryManagement'
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
                'ecr:CreateRepository',
                'ecr:DescribeRepositories',
                'ecr:PutLifecyclePolicy'
            )
            Resource = '*'
        },
        @{
            Sid = 'ECSAndTaskExecution'
            Effect = 'Allow'
            Action = @(
                'ecs:CreateCluster',
                'ecs:DescribeClusters',
                'ecs:RegisterTaskDefinition',
                'ecs:DeregisterTaskDefinition',
                'ecs:DescribeTaskDefinition',
                'ecs:CreateService',
                'ecs:UpdateService',
                'ecs:DescribeServices',
                'ecs:RunTask',
                'ecs:StopTask',
                'ecs:DescribeTasks'
            )
            Resource = '*'
        },
        @{
            Sid = 'IAMPassRoleForECS'
            Effect = 'Allow'
            Action = @('iam:PassRole')
            Resource = "arn:aws:iam::${activeAccount}:role/*ledger*"
        },
        @{
            Sid = 'VPCAndSecurityGroupManagement'
            Effect = 'Allow'
            Action = @(
                'ec2:DescribeVpcs',
                'ec2:CreateVpc',
                'ec2:DescribeSubnets',
                'ec2:CreateSubnet',
                'ec2:DescribeSecurityGroups',
                'ec2:CreateSecurityGroup',
                'ec2:AuthorizeSecurityGroupIngress',
                'ec2:AuthorizeSecurityGroupEgress',
                'ec2:DescribeInternetGateways',
                'ec2:CreateInternetGateway',
                'ec2:AttachInternetGateway',
                'ec2:DescribeRouteTables',
                'ec2:CreateRouteTable',
                'ec2:CreateRoute',
                'ec2:AssociateRouteTable'
            )
            Resource = '*'
        },
        @{
            Sid = 'RDSManagement'
            Effect = 'Allow'
            Action = @(
                'rds:CreateDBInstance',
                'rds:DescribeDBInstances',
                'rds:ModifyDBInstance',
                'rds:CreateDBSubnetGroup',
                'rds:DescribeDBSubnetGroups'
            )
            Resource = '*'
        },
        @{
            Sid = 'S3InvoiceStorage'
            Effect = 'Allow'
            Action = @(
                's3:CreateBucket',
                's3:ListBucket',
                's3:GetObject',
                's3:PutObject',
                's3:PutBucketEncryption',
                's3:PutPublicAccessBlock',
                's3:PutBucketCors'
            )
            Resource = 'arn:aws:s3:::ledgeragent-*'
        },
        @{
            Sid = 'SecretsManagerAccess'
            Effect = 'Allow'
            Action = @(
                'secretsmanager:CreateSecret',
                'secretsmanager:GetSecretValue',
                'secretsmanager:PutSecretValue',
                'secretsmanager:DescribeSecret'
            )
            Resource = "arn:aws:secretsmanager:${Region}:${activeAccount}:secret:ledgeragent/*"
        },
        @{
            Sid = 'CloudWatchLogsAccess'
            Effect = 'Allow'
            Action = @(
                'logs:CreateLogGroup',
                'logs:CreateLogStream',
                'logs:PutLogEvents',
                'logs:DescribeLogStreams',
                'logs:GetLogEvents'
            )
            Resource = "arn:aws:logs:${Region}:${activeAccount}:log-group:/ecs/ledgeragent-*"
        }
    )
}

$policyPath = Join-Path -Path $PSScriptRoot -ChildPath 'ledgeragent-ci-policy.json'
$policyObj | ConvertTo-Json -Depth 6 | Out-File -FilePath $policyPath -Encoding ascii
Write-Host "  [OK] Generated least-privilege policy: $policyPath" -ForegroundColor Green

# 4. Estimated Monthly Cost Summary
Write-Host ''
Write-Host '[4/4] Monthly Cost Estimation for Prereqs and IAM:' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  IAM Users and Policies:       $0.00 / month (Free)' -ForegroundColor Green
Write-Host '  AWS STS Verification:         $0.00 / month (Free)' -ForegroundColor Green
Write-Host '  Total Phase 8A Prereq Cost:   $0.00 / month' -ForegroundColor Green
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '[OK] 00-prereqs.ps1 verification passed successfully.' -ForegroundColor Green
Write-Host ''
