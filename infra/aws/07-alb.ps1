# =============================================================================
# 07-alb.ps1 - AWS Application Load Balancer & Path-Based Routing
# Region: ap-south-1 (Mumbai) | Account: 441214867393
# Standard: Windows PowerShell 5.1 Hardened (ASCII, ErrorActionPreference Continue)
# =============================================================================

[CmdletBinding()]
param(
    [string]$Region = 'ap-south-1',
    [string]$AlbName = 'ledgeragent-alb',
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
Write-Host '  [ALB] AWS Infrastructure - 07 Application Load Balancer' -ForegroundColor Cyan
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
$albSgId = $net.AlbSecurityGroupId

$subnetCsv = $publicSubnets -join ' '

# 1. Idempotent Target Group Creation (IP Target Type for Fargate)
Write-Host ''
Write-Host '[1/4] Configuring Target Groups (Frontend :80 and Backend :8000)...' -ForegroundColor Yellow

function Ensure-TargetGroup {
    param($TgName, $Port, $HealthPath)
    $tgCheck = Get-AwsJson -Arguments @('elbv2', 'describe-target-groups', '--names', $TgName, '--region', $Region, '--output', 'json')
    if ($tgCheck -and $tgCheck.TargetGroups.Count -gt 0) {
        Write-Host "  [INFO] Target Group '$TgName' exists." -ForegroundColor DarkCyan
        return $tgCheck.TargetGroups[0].TargetGroupArn
    }

    Write-Host "  [NEW] Creating Target Group '$TgName' (Port $Port, Path $HealthPath)..." -ForegroundColor Green
    $tgCreate = Get-AwsJson -Arguments @(
        'elbv2', 'create-target-group',
        '--name', $TgName,
        '--protocol', 'HTTP',
        '--port', "$Port",
        '--vpc-id', $vpcId,
        '--target-type', 'ip',
        '--health-check-protocol', 'HTTP',
        '--health-check-path', $HealthPath,
        '--health-check-interval-seconds', '15',
        '--health-check-timeout-seconds', '5',
        '--healthy-threshold-count', '2',
        '--unhealthy-threshold-count', '3',
        '--region', $Region,
        '--output', 'json'
    )
    return $tgCreate.TargetGroups[0].TargetGroupArn
}

$frontendTgArn = Ensure-TargetGroup -TgName 'ledgeragent-tg-frontend' -Port 80 -HealthPath '/health'
$backendTgArn  = Ensure-TargetGroup -TgName 'ledgeragent-tg-backend'  -Port 8000 -HealthPath '/api/v1/health'

Write-Host "  [OK] Target Groups Ready: Frontend ($frontendTgArn), Backend ($backendTgArn)" -ForegroundColor Green

# 2. Idempotent Application Load Balancer Creation
Write-Host ''
Write-Host "[2/4] Checking Application Load Balancer '$AlbName'..." -ForegroundColor Yellow

$albCheck = Get-AwsJson -Arguments @('elbv2', 'describe-load-balancers', '--names', $AlbName, '--region', $Region, '--output', 'json')

$albArn = ''
$albDns = ''

if ($albCheck -and $albCheck.LoadBalancers.Count -gt 0) {
    $albArn = $albCheck.LoadBalancers[0].LoadBalancerArn
    $albDns = $albCheck.LoadBalancers[0].DNSName
    Write-Host "  [INFO] ALB exists ($albDns)" -ForegroundColor DarkCyan
} else {
    Write-Host '  [NEW] Creating Internet-Facing Application Load Balancer in public subnets...' -ForegroundColor Green
    $albParams = @(
        'elbv2', 'create-load-balancer',
        '--name', $AlbName,
        '--subnets'
    ) + $publicSubnets + @(
        '--security-groups', $albSgId,
        '--scheme', 'internet-facing',
        '--type', 'application',
        '--region', $Region,
        '--output', 'json'
    )
    $albCreate = Get-AwsJson -Arguments $albParams
    $albArn = $albCreate.LoadBalancers[0].LoadBalancerArn
    $albDns = $albCreate.LoadBalancers[0].DNSName
}

Write-Host "  [OK] ALB DNS Name: http://${albDns}" -ForegroundColor Green

# 3. HTTP Listener :80 and Path-Based Routing Rule
Write-Host ''
Write-Host '[3/4] Configuring HTTP Listener :80 and Routing Rules...' -ForegroundColor Yellow

$listenerCheck = Get-AwsJson -Arguments @('elbv2', 'describe-listeners', '--load-balancer-arn', $albArn, '--region', $Region, '--output', 'json')

$listenerArn = ''
if ($listenerCheck -and $listenerCheck.Listeners.Count -gt 0) {
    $listenerArn = $listenerCheck.Listeners[0].ListenerArn
    Write-Host "  [INFO] HTTP Listener :80 exists." -ForegroundColor DarkCyan
} else {
    Write-Host '  [NEW] Creating HTTP Listener :80 (Default -> Frontend TG)...' -ForegroundColor Green
    $listenerCreate = Get-AwsJson -Arguments @(
        'elbv2', 'create-listener',
        '--load-balancer-arn', $albArn,
        '--protocol', 'HTTP',
        '--port', '80',
        '--default-actions', "Type=forward,TargetGroupArn=$frontendTgArn",
        '--region', $Region,
        '--output', 'json'
    )
    $listenerArn = $listenerCreate.Listeners[0].ListenerArn
}

# Rule 10: Path Pattern /api/v1/* -> Forward to Backend TG
$rulesCheck = Get-AwsJson -Arguments @('elbv2', 'describe-rules', '--listener-arn', $listenerArn, '--region', $Region, '--output', 'json')
$hasApiRule = $false
if ($rulesCheck -and $rulesCheck.Rules) {
    foreach ($r in $rulesCheck.Rules) {
        if ($r.Priority -eq '10') {
            $hasApiRule = $true
            break
        }
    }
}

if (-not $hasApiRule) {
    Write-Host "  [NEW] Creating Path Rule: /api/v1/* -> Backend Target Group..." -ForegroundColor Green
    & aws elbv2 create-rule `
        --listener-arn $listenerArn `
        --priority 10 `
        --conditions Field=path-pattern,Values='/api/v1/*' `
        --actions Type=forward,TargetGroupArn=$backendTgArn `
        --region $Region 2>&1 | Out-Null
    Write-Host "  [OK] Attached path routing rule for /api/v1/*." -ForegroundColor Green
} else {
    Write-Host "  [INFO] Path rule for /api/v1/* exists." -ForegroundColor DarkCyan
}

# 4. Attach Target Groups to ECS Services for Automatic Task Registration
Write-Host ''
Write-Host '[4/4] Attaching Target Groups to ECS Services...' -ForegroundColor Yellow

# Update backend service with load balancer target group
& aws ecs update-service `
    --cluster $ClusterName `
    --service 'ledgeragent-backend' `
    --load-balancers "targetGroupArn=$backendTgArn,containerName=backend,containerPort=8000" `
    --region $Region 2>&1 | Out-Null

# Update frontend service with load balancer target group
& aws ecs update-service `
    --cluster $ClusterName `
    --service 'ledgeragent-frontend' `
    --load-balancers "targetGroupArn=$frontendTgArn,containerName=frontend,containerPort=80" `
    --region $Region 2>&1 | Out-Null

# Save Outputs
$albOutput = @{
    AlbName = $AlbName
    AlbArn = $albArn
    AlbDnsName = $albDns
    FrontendTargetGroupArn = $frontendTgArn
    BackendTargetGroupArn = $backendTgArn
    ListenerArn = $listenerArn
    Region = $Region
    EndpointUrl = "http://${albDns}"
}
$albOutputFile = Join-Path -Path $PSScriptRoot -ChildPath 'alb-output.json'
$albOutput | ConvertTo-Json -Depth 4 | Out-File -FilePath $albOutputFile -Encoding ascii
Write-Host "  [SAVED] ALB metadata saved: $albOutputFile" -ForegroundColor Green

# 5. Monthly Cost Estimation
Write-Host ''
Write-Host '[Cost Breakdown: Application Load Balancer]' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  Application Load Balancer (Single Ingress): ~$16.00 / month' -ForegroundColor Green
Write-Host '  LCU (Load Balancer Capacity Units):        ~$0.50 / month' -ForegroundColor Green
Write-Host '  Target Groups and Routing Rules:           $0.00 / month' -ForegroundColor Green
Write-Host '  Estimated Monthly ALB Ingress Cost:        ~$16.50 / month' -ForegroundColor Green
Write-Host '  --------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  PUBLIC APPLICATION URL:" -ForegroundColor Yellow
Write-Host "  http://${albDns}" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ''
Write-Host '[OK] 07-alb.ps1 ALB deployment completed successfully.' -ForegroundColor Green
Write-Host ''
