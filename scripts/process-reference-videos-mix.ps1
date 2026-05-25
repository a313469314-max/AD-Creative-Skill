param(
    [Parameter(Mandatory = $true)]
    [string[]]$VideoPaths,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Slug,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$BaseDir,

    [string]$FfmpegPath,

    [string]$FfprobePath,

    [string]$ProductBriefPath,

    [switch]$Copy,

    [switch]$Move,

    [switch]$KeepWork,

    [int]$StoryboardFrames = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($VideoPaths.Count -lt 2) {
    throw 'mix mode requires at least two videos.'
}
if ($Copy -and $Move) {
    throw 'Use either -Copy or -Move, not both. Copy is the default.'
}
if ($StoryboardFrames -lt 4 -or $StoryboardFrames -gt 30) {
    throw 'StoryboardFrames must be between 4 and 30.'
}
if ($Name -match '[\\/:*?"<>|]') {
    throw "Name contains invalid filename characters: $Name"
}

function Resolve-FilePath {
    param([string]$Path)
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "Path not found: $Path"
    }
    return $resolved.Path
}

function Resolve-Executable {
    param([string]$ExplicitPath, [string]$CommandName)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return Resolve-FilePath $ExplicitPath
    }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "$CommandName not found. Run scripts/install-ffmpeg.ps1 or pass explicit paths."
    }
    return $cmd.Source
}

function Invoke-Logged {
    param(
        [string]$Exe,
        [string[]]$Arguments,
        [string]$LogPath,
        [switch]$AllowFailure
    )
    $stdoutPath = "$LogPath.stdout"
    $stderrPath = "$LogPath.stderr"
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Exe @Arguments > $stdoutPath 2> $stderrPath
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $combined = @()
    if (Test-Path -LiteralPath $stdoutPath) {
        $combined += Get-Content -LiteralPath $stdoutPath
        Remove-Item -LiteralPath $stdoutPath -Force
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $combined += Get-Content -LiteralPath $stderrPath
        Remove-Item -LiteralPath $stderrPath -Force
    }
    $combined | Set-Content -LiteralPath $LogPath -Encoding UTF8

    if ($exitCode -ne 0) {
        if ($AllowFailure) {
            return $false
        }
        throw "Command failed. See log: $LogPath"
    }
    if ($AllowFailure) {
        return $true
    }
    return $true
}

function Convert-ToNullableDouble {
    param($Value)
    if ($null -eq $Value) {
        return $null
    }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
    $parsed = 0.0
    if ([double]::TryParse($text, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        return $parsed
    }
    return $null
}

$ffmpeg = Resolve-Executable -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
$ffprobe = Resolve-Executable -ExplicitPath $FfprobePath -CommandName 'ffprobe'
if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = Join-Path (Get-Location).Path 'creative-materials'
}
New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
$baseDirResolved = Resolve-Path -LiteralPath $BaseDir

$datePrefix = Get-Date -Format 'yyyy-MM-dd'
$materialDir = Join-Path $baseDirResolved.Path "$datePrefix-$Slug-$Name"
if (Test-Path -LiteralPath $materialDir) {
    throw "Material folder already exists: $materialDir"
}
$outputsDir = Join-Path $materialDir 'outputs'
$systemDir = Join-Path $materialDir '_system-review'
$workDir = Join-Path $materialDir 'keyframes-work'
New-Item -ItemType Directory -Path $materialDir, $outputsDir, $systemDir, $workDir -Force | Out-Null

$productBriefOutputPath = Join-Path $materialDir 'product-brief.md'
if (-not [string]::IsNullOrWhiteSpace($ProductBriefPath)) {
    $resolvedProductBrief = Resolve-FilePath $ProductBriefPath
    Copy-Item -LiteralPath $resolvedProductBrief -Destination $productBriefOutputPath
} else {
@"
# 产品信息简报

在要求 AI 将这组参考视频映射到你的产品前，请先补全这里的信息。

## 产品基础信息

- 产品/游戏名称：TODO
- 品类/赛道：TODO
- 目标市场与受众：TODO
- 平台与投放渠道：TODO

## 核心玩法

- 核心循环：TODO
- 用户前 30 秒的真实体验：TODO
- 广告里可以真实展示的核心交互：TODO
- 成长、升级、merge、battle、puzzle、building、collection 或其他系统：TODO

## 可售卖 Hook

- 最强的幻想点或欲望点：TODO
- 当前已经具备的视觉资产：TODO
- 能承接这组共享参考方向的产品机制：TODO
- hook 之后的情绪回报：TODO

## 限制条件

- 必须展示：TODO
- 必须避免：TODO
- 制作限制：TODO
- 合规/平台限制：TODO

## 映射目标

- 获客目标：TODO
- 要测试的创意角度：TODO
- 成功指标：TODO

## 隐私提醒

请勿在此文件中填写 API keys、未公开财务数据、个人隐私信息或合作方私密数据。
"@ | Set-Content -LiteralPath $productBriefOutputPath -Encoding UTF8
}

$metadataItems = @()
$frameItems = @()
$videoIndex = 0
foreach ($path in $VideoPaths) {
    $videoIndex++
    $source = Resolve-FilePath $path
    $extension = [IO.Path]::GetExtension($source)
    if ([string]::IsNullOrWhiteSpace($extension)) { $extension = '.mp4' }
    $destName = 'video-{0:D2}-{1}{2}' -f $videoIndex, ([IO.Path]::GetFileNameWithoutExtension($source)), $extension
    $dest = Join-Path $materialDir $destName
    if ($Move) { Move-Item -LiteralPath $source -Destination $dest } else { Copy-Item -LiteralPath $source -Destination $dest }

    $probeJson = & $ffprobe @('-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', $dest) | Out-String
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed for video file: $dest" }
    $probe = $probeJson | ConvertFrom-Json
    $videoStreams = @($probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1)
    if ($videoStreams.Count -eq 0) {
        throw "No video stream found in input file: $dest. The file may be audio-only, corrupted, or unsupported."
    }
    $videoStream = $videoStreams[0]
    $duration = $null
    if ($videoStream.duration) {
        $duration = Convert-ToNullableDouble $videoStream.duration
    }
    if ($null -eq $duration -and $probe.format.duration) {
        $duration = Convert-ToNullableDouble $probe.format.duration
    }
    if ($null -eq $duration -or $duration -le 0) {
        throw "Cannot determine a valid video duration for input file: $dest"
    }
    $metadataItems += [ordered]@{
        index = $videoIndex
        file = $destName
        duration_seconds = [Math]::Round($duration, 3)
        width = $videoStream.width
        height = $videoStream.height
        codec = $videoStream.codec_name
    }

    $selectedDir = Join-Path $workDir ('selected-{0:D2}' -f $videoIndex)
    New-Item -ItemType Directory -Path $selectedDir -Force | Out-Null
    $framesForVideo = @()
    $startTime = 0.03
    $endTime = [Math]::Max($startTime, $duration - 0.35)
    for ($i = 0; $i -lt $StoryboardFrames; $i++) {
        $ratio = if ($StoryboardFrames -eq 1) { 0 } else { $i / ($StoryboardFrames - 1) }
        $timestamp = $startTime + (($endTime - $startTime) * $ratio)
        $frameName = 'selected-{0:D2}.jpg' -f ($i + 1)
        Invoke-Logged -Exe $ffmpeg -Arguments @(
            '-hide_banner', '-y',
            '-ss', ([string][Math]::Round($timestamp, 3)),
            '-i', $dest,
            '-frames:v', '1',
            '-q:v', '2',
            '-vf', 'scale=360:-1',
            '-update', '1',
            (Join-Path $selectedDir $frameName)
        ) -LogPath (Join-Path $workDir ('ffmpeg-video-{0:D2}-frame-{1:D2}.log' -f $videoIndex, ($i + 1))) | Out-Null
        $framesForVideo += [ordered]@{
            index = $i + 1
            timestamp_seconds = [Math]::Round($timestamp, 3)
        }
    }
    $sheet = Join-Path $materialDir ('keyframes-reference-storyboard-contact-sheet-{0}-video-{1:D2}.jpg' -f $Name, $videoIndex)
    $rows = [Math]::Ceiling($StoryboardFrames / 4)
    Invoke-Logged -Exe $ffmpeg -Arguments @(
        '-hide_banner', '-y',
        '-framerate', '1',
        '-i', (Join-Path $selectedDir 'selected-%02d.jpg'),
        '-vf', "tile=4x${rows}:padding=4:margin=2",
        '-frames:v', '1',
        $sheet
    ) -LogPath (Join-Path $workDir ('ffmpeg-sheet-video-{0:D2}.log' -f $videoIndex)) | Out-Null
    $frameItems += [ordered]@{
        video_index = $videoIndex
        video_file = $destName
        contact_sheet = Split-Path -Leaf $sheet
        frames = $framesForVideo
    }
}

[ordered]@{
    generated_at = (Get-Date).ToString('s')
    mode = 'mix'
    videos = $metadataItems
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $systemDir 'video_metadata.json') -Encoding UTF8

[ordered]@{
    generated_at = (Get-Date).ToString('s')
    mode = 'mix'
    frame_count_per_video = $StoryboardFrames
    videos = $frameItems
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $systemDir 'frame-index.json') -Encoding UTF8

$briefPath = Join-Path $materialDir 'brief.md'
@"
# $Name 混合参考视频创意任务

## 源视频列表

$(
    ($metadataItems | ForEach-Object { "- 视频 $($_.index)：$($_.file)，$($_.duration_seconds)s，$($_.width)x$($_.height)" }) -join "`r`n"
)

## 已生成素材

- 每条视频的关键帧联系表都在素材根目录。
- 系统文件位于 `_system-review/`。
- 汇总分析写入 `outputs/`。
- 产品信息：[product-brief.md](product-brief.md)

## 共用创意方向

TODO：描述这组视频共享的 hook、主题或创意方向。

## 产品映射上下文

在把这个共享方向映射到你的产品前，请先补全 `product-brief.md`。
"@ | Set-Content -LiteralPath $briefPath -Encoding UTF8

$sharedPath = Join-Path $outputsDir 'shared-analysis-mix.md'
@"
# 汇总分析

## 共用 Hook

TODO

## 视频差异点

TODO

## 可迁移结构

TODO

## 产品映射

请参考 `../product-brief.md`。如果其中仍然包含 TODO，或缺少产品特定信息，请列出缺失问题，并将产品映射标记为待补充。

## 创意方向池

TODO
"@ | Set-Content -LiteralPath $sharedPath -Encoding UTF8

$aiPackPath = Join-Path $systemDir 'ai-input-pack.md'
@"
# AI 输入包：$Name

这是一个同方向的多视频批次。

## 文件

- 任务说明：$briefPath
- 汇总分析：$sharedPath
- 产品信息：$productBriefOutputPath
- 帧索引：$(Join-Path $systemDir 'frame-index.json')
- 元数据：$(Join-Path $systemDir 'video_metadata.json')

## 规则

请把这些视频当作一个方向级创意任务来分析，不要拆分成多个独立的 single 视频文件夹。
做产品映射时请使用 product-brief.md。如果产品信息缺失，不要编造产品事实；输出缺失问题，并把产品映射保持为待补充状态。
"@ | Set-Content -LiteralPath $aiPackPath -Encoding UTF8

$manifestPath = Join-Path $systemDir 'run-manifest.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    mode = 'mix'
    script = $PSCommandPath
    material_folder = $materialDir
    ai_input_pack = $aiPackPath
    brief = $briefPath
    product_brief = $productBriefOutputPath
    outputs = @($sharedPath)
    video_count = $metadataItems.Count
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$materialResolved = Resolve-Path -LiteralPath $materialDir
$workResolved = Resolve-Path -LiteralPath $workDir
if (-not $workResolved.Path.StartsWith($materialResolved.Path)) {
    throw "Refusing to remove work directory outside material folder: $($workResolved.Path)"
}
if (-not $KeepWork) {
    Remove-Item -LiteralPath $workResolved.Path -Recurse -Force
}

$checkScript = Join-Path $PSScriptRoot 'check-creative-material.ps1'
$checkJson = & $checkScript -MaterialDir $materialDir -Json | Out-String
$checkExit = $LASTEXITCODE
$checkResult = $checkJson | ConvertFrom-Json

[ordered]@{
    material_folder = $materialDir
    ai_input_pack = $aiPackPath
    brief = $briefPath
    product_brief = $productBriefOutputPath
    shared_analysis = $sharedPath
    manifest = $manifestPath
    temp_work_dir_kept = [bool]$KeepWork
    check_status = $checkResult.status
    check_errors = $checkResult.errors
    check_warnings = $checkResult.warnings
    check_content_placeholders_remaining = $checkResult.content_placeholders_remaining
    check_placeholder_warnings = $checkResult.placeholder_warnings
} | ConvertTo-Json -Depth 6

if ($checkExit -ne 0) {
    exit $checkExit
}
