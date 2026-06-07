param(
    [Parameter(Mandatory = $true)]
    [string]$ProductId,

    [string]$Name,

    [string]$ProductsRoot,

    [switch]$Force,

    [switch]$NoRegistryUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\common.ps1')
. (Join-Path $PSScriptRoot 'lib\template-utils.ps1')

if ($ProductId -notmatch '^[a-z0-9][a-z0-9-]*$') {
    throw 'ProductId must use lowercase letters, numbers, and hyphens, and start with a letter or number.'
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = $ProductId
}

$skillRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
if ([string]::IsNullOrWhiteSpace($ProductsRoot)) {
    $ProductsRoot = Join-Path $skillRoot.Path 'products'
}

if (-not (Test-Path -LiteralPath $ProductsRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $ProductsRoot -Force | Out-Null
}

$productsRootResolved = Resolve-Path -LiteralPath $ProductsRoot
$productDir = Join-Path $productsRootResolved.Path $ProductId

if ((Test-Path -LiteralPath $productDir) -and -not $Force) {
    throw "Product directory already exists: $productDir. Use -Force to fill missing template files."
}

New-Item -ItemType Directory -Path $productDir -Force | Out-Null
foreach ($dir in @('recordings', 'materials', 'memory', 'playbooks')) {
    New-Item -ItemType Directory -Path (Join-Path $productDir $dir) -Force | Out-Null
}

$templateRoot = Join-Path $skillRoot.Path 'templates\product'
$templateFiles = [ordered]@{
    'product.yaml' = 'product.yaml'
    'product-profile.md' = 'product-profile.md'
    'gameplay-systems.md' = 'gameplay-systems.md'
    'hook-mapping.md' = 'hook-mapping.md'
    'asset-inventory.md' = 'asset-inventory.md'
    'creative-rules.md' = 'creative-rules.md'
    'metrics-policy.md' = 'metrics-policy.md'
    'recordings\README.md' = 'recordings\README.md'
    'recordings\recording-index.yaml' = 'recordings\recording-index.yaml'
    'materials\material-index.yaml' = 'materials\material-index.yaml'
    'memory\winning-patterns.md' = 'memory\winning-patterns.md'
    'memory\rejected-patterns.md' = 'memory\rejected-patterns.md'
    'memory\test-history.md' = 'memory\test-history.md'
}

$templateVariables = @{
    ProductId = $ProductId
    Name = $Name
}

foreach ($relativePath in $templateFiles.Keys) {
    $path = Join-Path $productDir $relativePath
    if ((Test-Path -LiteralPath $path -PathType Leaf) -and -not $Force) {
        continue
    }
    Write-TemplateFile `
        -TemplatePath (Join-Path $templateRoot $templateFiles[$relativePath]) `
        -OutputPath $path `
        -Variables $templateVariables
}

$registryPath = Join-Path $productsRootResolved.Path 'product-registry.yaml'
if (-not $NoRegistryUpdate) {
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        Write-Utf8File -Path $registryPath -Content "products:`r`n"
    }
    $registryContent = Get-Content -LiteralPath $registryPath -Raw
    if ($registryContent -notmatch "(?m)^\s*-\s*id:\s*$([Regex]::Escape($ProductId))\s*$") {
        Add-Content -LiteralPath $registryPath -Encoding UTF8 -Value @"
  - id: $ProductId
    name: $Name
    profile_dir: products/$ProductId
    primary_playbooks: []
    notes: "Independent product directory."
"@
    }
}

[ordered]@{
    product_id = $ProductId
    product_dir = (Resolve-Path -LiteralPath $productDir).Path
    registry_updated = (-not $NoRegistryUpdate)
} | ConvertTo-Json -Depth 4
