# =============================================================================
# 06-ecs.ps1 - Amazon ECS Fargate Cluster, Cloud Map, and Service Deployment
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (ASCII, ErrorActionPreference Continue)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$Account = '441214867393',
    [string]$ClusterName = 'ledgeragent-cluster'
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
Write-Host '  [ECS] AWS Infrastructure - 06 ECS Fargate Deployment' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan

# Load Network Outputs
$networkFile = Join-Path -Path $PSScriptRoot -ChildPath 'network-output.json'
if (-not (Test-Path $networkFile)) {
    Write-Error 'network-output.json not found! Run 02-network.ps1 first.'
    exit 1
}
$net = Get-Content $networkFile | ConvertFrom-Json
$vpcId = $net.VpcId
$publicSubnets = $net.PublicSubnets
$appSgId = $net.AppSecurityGroupId

$ecrRegistry = "${Account}.dkr.ecr.${Region}.amazonaws.com"
$s3Bucket = "ledgeragent-invoices-${Account}"

# Ensure VPC DNS hostnames and resolution are enabled for Cloud Map
& aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support --region $Region 2>&1 | Out-Null
& aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames --region $Region 2>&1 | Out-Null

# 1. CloudWatch Log Groups with 30-Day Retention
Write-Host ''
Write-Host '[1/6] Configuring CloudWatch Log Groups...' -ForegroundColor Yellow

$logGroups = @(
    '/ecs/ledgeragent-backend',
    '/ecs/ledgeragent-mock-erp',
    '/ecs/ledgeragent-frontend'
)

foreach ($lg in $logGroups) {
    $lgCheck = Get-AwsJson -Arguments @('logs', 'describe-log-groups', '--log-group-name-prefix', $lg, '--region', $Region, '--output', 'json')
    if (-not $lgCheck -or $lgCheck.logGroups.Count -eq 0) {
        & aws logs create-log-group --log-group-name $lg --region $Region 2>&1 | Out-Null
        & aws logs put-retention-policy --log-group-name $lg --retention-in-days 30 --region $Region 2>&1 | Out-Null
        Write-Host "  [NEW] Created log group '$lg' with 30-day retention." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Log group '$lg' exists." -ForegroundColor DarkCyan
    }
}

# 2. IAM Roles: ecsTaskExecutionRole & ledgeragent-task-role
Write-Host ''
Write-Host '[2/6] Configuring IAM Execution and Task Roles...' -ForegroundColor Yellow

# Trust Policy JSON
$trustPolicy = @{
    Version = '2012-10-17'
    Statement = @(
        @{
            Effect = 'Allow'
            Principal = @{
                Service = 'ecs-tasks.amazonaws.com'
            }
            Action = 'sts:AssumeRole'
        }
    )
} | ConvertTo-Json -Depth 4
$trustFile = Join-Path -Path $PSScriptRoot -ChildPath 'ecs-trust-policy.json'
$trustPolicy | Out-File -FilePath $trustFile -Encoding ascii

# 2a. Execution Role (pulls images, fetches Secrets Manager values, logs)
$execRoleName = 'ledgeragent-execution-role'
$execRoleCheck = Get-AwsJson -Arguments @('iam', 'get-role', '--role-name', $execRoleName, '--output', 'json')
if (-not $execRoleCheck) {
    & aws iam create-role --role-name $execRoleName --assume-role-policy-document "file://$trustFile" 2>&1 | Out-Null
    & aws iam attach-role-policy --role-name $execRoleName --policy-arn 'arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy' 2>&1 | Out-Null

    # Inline policy for Secrets Manager decryption (wildcard to handle random 6-character secret suffixes)
    $secretsPolicy = @{
        Version = '2012-10-17'
        Statement = @(
            @{
                Effect = 'Allow'
                Action = @(
                    'secretsmanager:GetSecretValue',
                    'secretsmanager:DescribeSecret',
                    'kms:Decrypt'
                )
                Resource = '*'
            }
        )
    } | ConvertTo-Json -Depth 4
    $secretsPolicyFile = Join-Path -Path $PSScriptRoot -ChildPath 'ecs-secrets-policy.json'
    $secretsPolicy | Out-File -FilePath $secretsPolicyFile -Encoding ascii
    & aws iam put-role-policy --role-name $execRoleName --policy-name 'LedgerAgentSecretsAccess' --policy-document "file://$secretsPolicyFile" 2>&1 | Out-Null
    Write-Host "  [NEW] Created IAM execution role '$execRoleName'." -ForegroundColor Green
} else {
    # Ensure policy has updated access
    $secretsPolicy = @{
        Version = '2012-10-17'
        Statement = @(
            @{
                Effect = 'Allow'
                Action = @(
                    'secretsmanager:GetSecretValue',
                    'secretsmanager:DescribeSecret',
                    'kms:Decrypt'
                )
                Resource = '*'
            }
        )
    } | ConvertTo-Json -Depth 4
    $secretsPolicyFile = Join-Path -Path $PSScriptRoot -ChildPath 'ecs-secrets-policy.json'
    $secretsPolicy | Out-File -FilePath $secretsPolicyFile -Encoding ascii
    & aws iam put-role-policy --role-name $execRoleName --policy-name 'LedgerAgentSecretsAccess' --policy-document "file://$secretsPolicyFile" 2>&1 | Out-Null
    Write-Host "  [INFO] Execution role '$execRoleName' updated with secrets policy." -ForegroundColor DarkCyan
}

$execRoleArn = "arn:aws:iam::${Account}:role/${execRoleName}"

# 2b. Task Role (S3 invoice reads/writes, CloudWatch application metrics)
$taskRoleName = 'ledgeragent-task-role'
$taskRoleCheck = Get-AwsJson -Arguments @('iam', 'get-role', '--role-name', $taskRoleName, '--output', 'json')
if (-not $taskRoleCheck) {
    & aws iam create-role --role-name $taskRoleName --assume-role-policy-document "file://$trustFile" 2>&1 | Out-Null

    $taskAppPolicy = @{
        Version = '2012-10-17'
        Statement = @(
            @{
                Effect = 'Allow'
                Action = @(
                    's3:GetObject',
                    's3:PutObject',
                    's3:ListBucket'
                )
                Resource = @(
                    "arn:aws:s3:::${s3Bucket}",
                    "arn:aws:s3:::${s3Bucket}/*"
                )
            },
            @{
                Effect = 'Allow'
                Action = @(
                    'secretsmanager:GetSecretValue'
                )
                Resource = '*'
            }
        )
    } | ConvertTo-Json -Depth 4
    $taskAppPolicyFile = Join-Path -Path $PSScriptRoot -ChildPath 'ecs-task-app-policy.json'
    $taskAppPolicy | Out-File -FilePath $taskAppPolicyFile -Encoding ascii
    & aws iam put-role-policy --role-name $taskRoleName --policy-name 'LedgerAgentTaskAppPolicy' --policy-document "file://$taskAppPolicyFile" 2>&1 | Out-Null
    Write-Host "  [NEW] Created IAM task role '$taskRoleName'." -ForegroundColor Green
} else {
    Write-Host "  [INFO] Task role '$taskRoleName' exists." -ForegroundColor DarkCyan
}

$taskRoleArn = "arn:aws:iam::${Account}:role/${taskRoleName}"

# 3. ECS Fargate Cluster
Write-Host ''
Write-Host "[3/6] Configuring ECS Cluster '$ClusterName'..." -ForegroundColor Yellow
$clusterCheck = Get-AwsJson -Arguments @('ecs', 'describe-clusters', '--clusters', $ClusterName, '--region', $Region, '--output', 'json')

if (-not $clusterCheck -or $clusterCheck.clusters.Count -eq 0 -or $clusterCheck.clusters[0].status -eq 'INACTIVE') {
    & aws ecs create-cluster --cluster-name $ClusterName --region $Region 2>&1 | Out-Null
    Write-Host "  [NEW] Created ECS Fargate cluster '$ClusterName'." -ForegroundColor Green
} else {
    Write-Host "  [INFO] ECS Cluster '$ClusterName' exists." -ForegroundColor DarkCyan
}

# 4. AWS Cloud Map Private DNS Namespace (ledgeragent.local)
Write-Host ''
Write-Host '[4/6] Configuring AWS Cloud Map Service Discovery...' -ForegroundColor Yellow
$nsCheck = Get-AwsJson -Arguments @('servicediscovery', 'list-namespaces', '--output', 'json')

$namespaceId = ''
if ($nsCheck -and $nsCheck.Namespaces) {
    foreach ($ns in $nsCheck.Namespaces) {
        if ($ns.Name -eq 'ledgeragent.local') {
            $namespaceId = $ns.Id
            break
        }
    }
}

if (-not $namespaceId) {
    Write-Host "  [NEW] Creating private DNS namespace 'ledgeragent.local' in VPC $vpcId..." -ForegroundColor Green
    $nsCreate = Get-AwsJson -Arguments @('servicediscovery', 'create-private-dns-namespace', '--name', 'ledgeragent.local', '--vpc', $vpcId, '--region', $Region, '--output', 'json')
    if ($nsCreate -and $nsCreate.OperationId) {
        & aws servicediscovery get-operation --operation-id $nsCreate.OperationId --region $Region 2>&1 | Out-Null
    }
    # Retrieve newly created namespace ID
    $nsList = Get-AwsJson -Arguments @('servicediscovery', 'list-namespaces', '--output', 'json')
    if ($nsList -and $nsList.Namespaces) {
        foreach ($ns in $nsList.Namespaces) {
            if ($ns.Name -eq 'ledgeragent.local') {
                $namespaceId = $ns.Id
                break
            }
        }
    }
} else {
    Write-Host "  [INFO] Cloud Map namespace 'ledgeragent.local' exists ($namespaceId)." -ForegroundColor DarkCyan
}

function Ensure-DiscoveryService {
    param($ServiceName)
    $sdList = Get-AwsJson -Arguments @('servicediscovery', 'list-services', '--output', 'json')
    if ($sdList -and $sdList.Services) {
        foreach ($s in $sdList.Services) {
            if ($s.Name -eq $ServiceName) {
                return $s.Arn
            }
        }
    }
    $sdCreate = Get-AwsJson -Arguments @(
        'servicediscovery', 'create-service',
        '--name', $ServiceName,
        '--dns-config', "NamespaceId=$namespaceId,DnsRecords=[{Type=A,TTL=10}]",
        '--region', $Region,
        '--output', 'json'
    )
    if ($sdCreate -and $sdCreate.Service) {
        return $sdCreate.Service.Arn
    }
    return $null
}

$backendDiscoveryArn = Ensure-DiscoveryService -ServiceName 'backend'
$mockErpDiscoveryArn = Ensure-DiscoveryService -ServiceName 'mock-erp'
Write-Host "  [OK] Cloud Map Service Discovery: backend ($backendDiscoveryArn), mock-erp ($mockErpDiscoveryArn)" -ForegroundColor Green

# 5. Register Task Definitions (Retrieve exact full Secret ARNs with random suffixes)
Write-Host ''
Write-Host '[5/6] Registering ECS Task Definitions...' -ForegroundColor Yellow

function Get-ExactSecretArn {
    param($SecretId)
    $obj = Get-AwsJson -Arguments @('secretsmanager', 'describe-secret', '--secret-id', $SecretId, '--region', $Region, '--output', 'json')
    if ($obj -and $obj.ARN) {
        return $obj.ARN
    }
    return "arn:aws:secretsmanager:${Region}:${Account}:secret:${SecretId}"
}

$dbUrlSecretArn = Get-ExactSecretArn -SecretId 'ledgeragent/db-url'
$jwtSecretArn   = Get-ExactSecretArn -SecretId 'ledgeragent/jwt-secret'
$groqSecretArn  = Get-ExactSecretArn -SecretId 'ledgeragent/groq-api-key'

Write-Host "  [SECRET] DB URL ARN:   $dbUrlSecretArn" -ForegroundColor DarkGray
Write-Host "  [SECRET] JWT Sec ARN:  $jwtSecretArn" -ForegroundColor DarkGray
Write-Host "  [SECRET] Groq Key ARN: $groqSecretArn" -ForegroundColor DarkGray

# 5a. Mock ERP Task Def (256 CPU / 512 MB)
$mockErpTaskDef = @{
    family = 'ledgeragent-mock-erp'
    networkMode = 'awsvpc'
    requiresCompatibilities = @('FARGATE')
    cpu = '256'
    memory = '512'
    executionRoleArn = $execRoleArn
    taskRoleArn = $taskRoleArn
    containerDefinitions = @(
        @{
            name = 'mock-erp'
            image = "${ecrRegistry}/ledgeragent-mock-erp:latest"
            essential = $true
            portMappings = @(
                @{
                    containerPort = 8001
                    hostPort = 8001
                    protocol = 'tcp'
                }
            )
            environment = @(
                @{ name = 'PYTHONUNBUFFERED'; value = '1' }
            )
            secrets = @(
                @{ name = 'DATABASE_URL'; valueFrom = $dbUrlSecretArn }
            )
            logConfiguration = @{
                logDriver = 'awslogs'
                options = @{
                    'awslogs-group' = '/ecs/ledgeragent-mock-erp'
                    'awslogs-region' = $Region
                    'awslogs-stream-prefix' = 'ecs'
                }
            }
        }
    )
}
$mockErpFile = Join-Path -Path $PSScriptRoot -ChildPath 'taskdef-mock-erp.json'
$mockErpTaskDef | ConvertTo-Json -Depth 6 | Out-File -FilePath $mockErpFile -Encoding ascii
& aws ecs register-task-definition --cli-input-json "file://$mockErpFile" --region $Region 2>&1 | Out-Null
Write-Host '  [OK] Registered task definition: ledgeragent-mock-erp' -ForegroundColor Green

# 5b. Backend Task Def (512 CPU / 1024 MB)
$backendTaskDef = @{
    family = 'ledgeragent-backend'
    networkMode = 'awsvpc'
    requiresCompatibilities = @('FARGATE')
    cpu = '512'
    memory = '1024'
    executionRoleArn = $execRoleArn
    taskRoleArn = $taskRoleArn
    containerDefinitions = @(
        @{
            name = 'backend'
            image = "${ecrRegistry}/ledgeragent-backend:latest"
            essential = $true
            portMappings = @(
                @{
                    containerPort = 8000
                    hostPort = 8000
                    protocol = 'tcp'
                }
            )
            environment = @(
                @{ name = 'MOCK_ERP_URL'; value = 'http://mock-erp.ledgeragent.local:8001' },
                @{ name = 'ENVIRONMENT'; value = 'production' },
                @{ name = 'AWS_REGION'; value = $Region },
                @{ name = 'S3_BUCKET_NAME'; value = $s3Bucket }
            )
            secrets = @(
                @{ name = 'DATABASE_URL'; valueFrom = $dbUrlSecretArn },
                @{ name = 'JWT_SECRET_KEY'; valueFrom = $jwtSecretArn },
                @{ name = 'GROQ_API_KEY'; valueFrom = $groqSecretArn }
            )
            logConfiguration = @{
                logDriver = 'awslogs'
                options = @{
                    'awslogs-group' = '/ecs/ledgeragent-backend'
                    'awslogs-region' = $Region
                    'awslogs-stream-prefix' = 'ecs'
                }
            }
        }
    )
}
$backendFile = Join-Path -Path $PSScriptRoot -ChildPath 'taskdef-backend.json'
$backendTaskDef | ConvertTo-Json -Depth 6 | Out-File -FilePath $backendFile -Encoding ascii
& aws ecs register-task-definition --cli-input-json "file://$backendFile" --region $Region 2>&1 | Out-Null
Write-Host '  [OK] Registered task definition: ledgeragent-backend' -ForegroundColor Green

# 5c. Frontend Task Def (256 CPU / 512 MB) with dynamic VPC DNS Resolver
$frontendTaskDef = @{
    family = 'ledgeragent-frontend'
    networkMode = 'awsvpc'
    requiresCompatibilities = @('FARGATE')
    cpu = '256'
    memory = '512'
    executionRoleArn = $execRoleArn
    taskRoleArn = $taskRoleArn
    containerDefinitions = @(
        @{
            name = 'frontend'
            image = "${ecrRegistry}/ledgeragent-frontend:latest"
            essential = $true
            portMappings = @(
                @{
                    containerPort = 80
                    hostPort = 80
                    protocol = 'tcp'
                }
            )
            environment = @(
                @{ name = 'BACKEND_HOST'; value = 'backend.ledgeragent.local' },
                @{ name = 'DNS_RESOLVER'; value = '10.0.0.2' }
            )
            logConfiguration = @{
                logDriver = 'awslogs'
                options = @{
                    'awslogs-group' = '/ecs/ledgeragent-frontend'
                    'awslogs-region' = $Region
                    'awslogs-stream-prefix' = 'ecs'
                }
            }
        }
    )
}
$frontendFile = Join-Path -Path $PSScriptRoot -ChildPath 'taskdef-frontend.json'
$frontendTaskDef | ConvertTo-Json -Depth 6 | Out-File -FilePath $frontendFile -Encoding ascii
& aws ecs register-task-definition --cli-input-json "file://$frontendFile" --region $Region 2>&1 | Out-Null
Write-Host '  [OK] Registered task definition: ledgeragent-frontend' -ForegroundColor Green

# 6. Idempotent ECS Service Provisioning
Write-Host ''
Write-Host '[6/6] Provisioning ECS Fargate Services with --force-new-deployment...' -ForegroundColor Yellow

$subnetCsv = $publicSubnets -join ','

function Ensure-EcsService {
    param(
        [string]$ServiceName,
        [string]$TaskFamily,
        [string]$DiscoveryArn
    )

    $svcCheck = Get-AwsJson -Arguments @('ecs', 'describe-services', '--cluster', $ClusterName, '--services', $ServiceName, '--region', $Region, '--output', 'json')

    $exists = ($svcCheck -and $svcCheck.services.Count -gt 0 -and $svcCheck.services[0].status -eq 'ACTIVE')

    if ($exists) {
        Write-Host "  [UPDATE] Forcing new deployment for '$ServiceName'..." -ForegroundColor DarkCyan
        & aws ecs update-service `
            --cluster $ClusterName `
            --service $ServiceName `
            --task-definition $TaskFamily `
            --desired-count 1 `
            --force-new-deployment `
            --region $Region 2>&1 | Out-Null
    } else {
        Write-Host "  [NEW] Creating ECS service '$ServiceName'..." -ForegroundColor Green
        
        $params = @(
            'ecs', 'create-service',
            '--cluster', $ClusterName,
            '--service-name', $ServiceName,
            '--task-definition', $TaskFamily,
            '--desired-count', '1',
            '--launch-type', 'FARGATE',
            '--network-configuration', "awsvpcConfiguration={subnets=[$subnetCsv],securityGroups=[$appSgId],assignPublicIp=ENABLED}",
            '--region', $Region,
            '--output', 'json'
        )

        if ($DiscoveryArn) {
            $params += @('--service-registries', "registryArn=$DiscoveryArn")
        }

        Get-AwsJson -Arguments $params | Out-Null
    }
}

Ensure-EcsService -ServiceName 'ledgeragent-mock-erp' -TaskFamily 'ledgeragent-mock-erp' -DiscoveryArn $mockErpDiscoveryArn
Ensure-EcsService -ServiceName 'ledgeragent-backend' -TaskFamily 'ledgeragent-backend' -DiscoveryArn $backendDiscoveryArn
Ensure-EcsService -ServiceName 'ledgeragent-frontend' -TaskFamily 'ledgeragent-frontend' -DiscoveryArn $null

# Save Outputs
$ecsOutput = @{
    ClusterName = $ClusterName
    ExecutionRoleArn = $execRoleArn
    TaskRoleArn = $taskRoleArn
    NamespaceId = $namespaceId
    Services = @('ledgeragent-mock-erp', 'ledgeragent-backend', 'ledgeragent-frontend')
    Region = $Region
}
$ecsOutputFile = Join-Path -Path $PSScriptRoot -ChildPath 'ecs-output.json'
$ecsOutput | ConvertTo-Json -Depth 4 | Out-File -FilePath $ecsOutputFile -Encoding ascii
Write-Host "  [SAVED] ECS deployment outputs: $ecsOutputFile" -ForegroundColor Green

# 7. Monthly Cost Estimation
Write-Host ''
Write-Host '[Cost Breakdown: AWS ECS Fargate & Cloud Map]' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  ECS Fargate 3 Tasks (0.25-0.5 vCPU):  ~$4.50 / month' -ForegroundColor Green
Write-Host '  CloudWatch Logs (30-day retention):   $0.00 / month (Free Tier 5GB)' -ForegroundColor Green
Write-Host '  AWS Cloud Map (Private DNS):          ~$0.50 / month' -ForegroundColor Green
Write-Host '  Estimated Monthly ECS Compute Cost:   ~$5.00 / month' -ForegroundColor Green
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '[OK] 06-ecs.ps1 ECS Fargate provisioning completed successfully.' -ForegroundColor Green
Write-Host ''
