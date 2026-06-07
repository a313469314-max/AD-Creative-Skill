param(
    [Parameter(Mandatory = $true)]
    [string]$VideoPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Slug,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$BaseDir,

    [string]$FfmpegPath,

    [string]$FfprobePath,

    [string]$ProductBriefPath,

    [string]$ProductId,

    [string]$ProductProfileDir,

    [switch]$Copy,

    [switch]$Move,

    [switch]$KeepWork,

    [int]$StoryboardFrames = 12,

    [double]$SceneThreshold = 0.23,

    [switch]$StrictCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$startScript = Join-Path $scriptDir 'start-reference-video.ps1'
$checkScript = Join-Path $scriptDir 'check-creative-material.ps1'

$startArgs = @{
    VideoPath = $VideoPath
    Slug = $Slug
    Name = $Name
    StoryboardFrames = $StoryboardFrames
    SceneThreshold = $SceneThreshold
}
if (-not [string]::IsNullOrWhiteSpace($BaseDir)) { $startArgs.BaseDir = $BaseDir }
if (-not [string]::IsNullOrWhiteSpace($FfmpegPath)) { $startArgs.FfmpegPath = $FfmpegPath }
if (-not [string]::IsNullOrWhiteSpace($FfprobePath)) { $startArgs.FfprobePath = $FfprobePath }
if (-not [string]::IsNullOrWhiteSpace($ProductBriefPath)) { $startArgs.ProductBriefPath = $ProductBriefPath }
if (-not [string]::IsNullOrWhiteSpace($ProductId)) { $startArgs.ProductId = $ProductId }
if (-not [string]::IsNullOrWhiteSpace($ProductProfileDir)) { $startArgs.ProductProfileDir = $ProductProfileDir }
if ($Copy) { $startArgs.Copy = $true }
if ($Move) { $startArgs.Move = $true }
if ($KeepWork) { $startArgs.KeepWork = $true }

$startJson = & $startScript @startArgs | Out-String
if ($LASTEXITCODE -ne 0) {
    throw 'start-reference-video.ps1 failed.'
}
$startResult = $startJson | ConvertFrom-Json

$checkArgs = @{
    MaterialDir = $startResult.material_folder
    Json = $true
}
if ($StrictCheck) { $checkArgs.Strict = $true }

$checkJson = & $checkScript @checkArgs | Out-String
$checkExit = $LASTEXITCODE
$checkResult = $checkJson | ConvertFrom-Json

[ordered]@{
    material_folder = $startResult.material_folder
    ai_input_pack = $startResult.ai_input_pack
    final_storyboard_sheet = $startResult.final_storyboard_sheet
    frame_index = $startResult.frame_index
    brief = $startResult.brief
    product_brief = $startResult.product_brief
    reference_storyboard = $startResult.reference_storyboard
    creative_directions = $startResult.creative_directions
    manifest = $startResult.manifest
    product_context = $startResult.product_context
    check_status = $checkResult.status
    check_errors = $checkResult.errors
    check_warnings = $checkResult.warnings
    check_content_placeholders_remaining = $checkResult.content_placeholders_remaining
    check_placeholder_warnings = $checkResult.placeholder_warnings
    next_step = 'AI 先阅读 methodology/ad-creative-methodology.md、_system-review/ai-input-pack.md、product-brief.md 和 keyframe contact sheet；需要更细方法解释时再查阅 methodology/full/README.md。如果提供了产品上下文，按产品事实优先级补充产品适配度、可承接机制、可用资产和历史素材依据；如果本次对话另附当前产品真实录屏，该录屏分析只用于本次产品判断。如果 product-brief.md 仍不完整，产品映射保持为待补充。'
} | ConvertTo-Json -Depth 8

if ($checkExit -ne 0) {
    exit $checkExit
}
