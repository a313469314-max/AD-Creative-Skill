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

    [switch]$Copy,

    [switch]$Move,

    [switch]$KeepWork,

    [int]$StoryboardFrames = 12,

    [double]$SceneThreshold = 0.23
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-SafeFileNamePart {
    param([string]$Value, [string]$FieldName)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$FieldName cannot be empty."
    }
    if ($Value -match '[\\/:*?"<>|]') {
        throw "$FieldName contains invalid filename characters: $Value"
    }
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
        $paramName = if ($CommandName -eq 'ffmpeg') { 'FfmpegPath' } elseif ($CommandName -eq 'ffprobe') { 'FfprobePath' } else { "$($CommandName)Path" }
        throw "Required executable not found on PATH: $CommandName. Install FFmpeg first, then rerun scripts/check-environment.ps1. Windows: winget install Gyan.FFmpeg. macOS: brew install ffmpeg. Linux: use your package manager. If it is already installed, pass -$paramName with the full executable path."
    }
    return $cmd.Source
}

function Parse-Fps {
    param([string]$Rate)
    if (-not $Rate -or $Rate -notmatch '/') {
        return $null
    }
    $parts = $Rate.Split('/')
    $num = [double]$parts[0]
    $den = [double]$parts[1]
    if ($den -eq 0) {
        return $null
    }
    return [Math]::Round($num / $den, 4)
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

function New-TileSheet {
    param(
        [string]$Ffmpeg,
        [string]$Pattern,
        [int]$Count,
        [int]$Columns,
        [string]$OutputPath,
        [string]$LogPath
    )
    if ($Count -le 0) {
        return $false
    }
    $rows = [Math]::Ceiling($Count / $Columns)
    Invoke-Logged -Exe $Ffmpeg -Arguments @(
        '-hide_banner', '-y',
        '-framerate', '1',
        '-i', $Pattern,
        '-vf', "tile=${Columns}x${rows}:padding=4:margin=2",
        '-frames:v', '1',
        $OutputPath
    ) -LogPath $LogPath | Out-Null
    return $true
}

Assert-SafeFileNamePart -Value $Name -FieldName 'Name'
if ($Copy -and $Move) {
    throw 'Use either -Copy or -Move, not both. Copy is the default.'
}
if ($StoryboardFrames -lt 4 -or $StoryboardFrames -gt 30) {
    throw 'StoryboardFrames must be between 4 and 30.'
}

$ffmpeg = Resolve-Executable -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
$ffprobe = Resolve-Executable -ExplicitPath $FfprobePath -CommandName 'ffprobe'

if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = Join-Path (Get-Location).Path 'creative-materials'
}
if (-not (Test-Path -LiteralPath $BaseDir -PathType Container)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}
$baseDirResolved = Resolve-Path -LiteralPath $BaseDir

$sourceVideo = Resolve-FilePath $VideoPath
$extension = [IO.Path]::GetExtension($sourceVideo)
if ([string]::IsNullOrWhiteSpace($extension)) {
    $extension = '.mp4'
}

$datePrefix = Get-Date -Format 'yyyy-MM-dd'
$materialName = "$datePrefix-$Slug-$Name"
$materialDir = Join-Path $baseDirResolved.Path $materialName
if (Test-Path -LiteralPath $materialDir) {
    throw "Material folder already exists: $materialDir"
}

New-Item -ItemType Directory -Path $materialDir | Out-Null
$outputsDir = Join-Path $materialDir 'outputs'
$systemDir = Join-Path $materialDir '_system-review'
New-Item -ItemType Directory -Path $outputsDir, $systemDir | Out-Null

$destVideo = Join-Path $materialDir "original-$Name$extension"
if ($Move) {
    Move-Item -LiteralPath $sourceVideo -Destination $destVideo
    $videoAction = 'moved'
} else {
    Copy-Item -LiteralPath $sourceVideo -Destination $destVideo
    $videoAction = 'copied'
}

$productBriefOutputPath = Join-Path $materialDir 'product-brief.md'
if (-not [string]::IsNullOrWhiteSpace($ProductBriefPath)) {
    $resolvedProductBrief = Resolve-FilePath $ProductBriefPath
    Copy-Item -LiteralPath $resolvedProductBrief -Destination $productBriefOutputPath
} else {
@"
# 产品信息简报

在要求 AI 将参考视频映射到你的产品前，请先补全这里的信息。

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
- 能承接参考 hook 的产品机制：TODO
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

$probeJson = & $ffprobe -v error -print_format json -show_streams -show_format $destVideo | Out-String
if ($LASTEXITCODE -ne 0) {
    throw 'ffprobe failed.'
}
$probe = $probeJson | ConvertFrom-Json
$videoStreams = @($probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1)
if ($videoStreams.Count -eq 0) {
    throw 'No video stream found.'
}
$videoStream = $videoStreams[0]
$audioStreams = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1)
$audioStream = if ($audioStreams.Count -gt 0) { $audioStreams[0] } else { $null }

$duration = $null
if ($videoStream.duration) {
    $duration = [double]$videoStream.duration
} elseif ($probe.format.duration) {
    $duration = [double]$probe.format.duration
}
if (-not $duration -or $duration -le 0) {
    throw 'Cannot determine video duration.'
}

$metadataPath = Join-Path $systemDir 'video_metadata.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    source_video_action = $videoAction
    material_folder = $materialDir
    file = Split-Path -Leaf $destVideo
    video = [ordered]@{
        codec = $videoStream.codec_name
        width = $videoStream.width
        height = $videoStream.height
        r_frame_rate = $videoStream.r_frame_rate
        fps = Parse-Fps $videoStream.r_frame_rate
        duration_seconds = [Math]::Round($duration, 3)
        nb_frames = $videoStream.nb_frames
    }
    audio = if ($audioStream) {
        [ordered]@{
            codec = $audioStream.codec_name
            duration_seconds = if ($audioStream.duration) { [Math]::Round([double]$audioStream.duration, 3) } else { $null }
        }
    } else {
        $null
    }
    format = [ordered]@{
        duration_seconds = if ($probe.format.duration) { [Math]::Round([double]$probe.format.duration, 3) } else { $null }
        size_bytes = if ($probe.format.size) { [int64]$probe.format.size } else { $null }
        bit_rate = $probe.format.bit_rate
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

$workDir = Join-Path $materialDir 'keyframes-work'
$uniformDir = Join-Path $workDir 'uniform'
$sceneDir = Join-Path $workDir 'scene'
$selectedDir = Join-Path $workDir 'selected'
New-Item -ItemType Directory -Path $uniformDir, $sceneDir, $selectedDir -Force | Out-Null

Invoke-Logged -Exe $ffmpeg -Arguments @(
    '-hide_banner', '-y',
    '-i', $destVideo,
    '-vf', 'fps=1,scale=360:-1',
    (Join-Path $uniformDir 'uniform-%03d.jpg')
) -LogPath (Join-Path $workDir 'ffmpeg-uniform.log') | Out-Null

Invoke-Logged -Exe $ffmpeg -Arguments @(
    '-hide_banner', '-y',
    '-i', $destVideo,
    '-vf', "select='gt(scene,$SceneThreshold)',scale=360:-1",
    '-vsync', 'vfr',
    (Join-Path $sceneDir 'scene-%03d.jpg')
) -LogPath (Join-Path $workDir 'ffmpeg-scene.log') -AllowFailure | Out-Null

$startTime = 0.03
$endTime = [Math]::Max($startTime, $duration - 0.35)
$selectedFrames = @()
for ($i = 0; $i -lt $StoryboardFrames; $i++) {
    $ratio = if ($StoryboardFrames -eq 1) { 0 } else { $i / ($StoryboardFrames - 1) }
    $timestamp = $startTime + (($endTime - $startTime) * $ratio)
    $nameForFrame = 'selected-{0:D2}.jpg' -f ($i + 1)
    Invoke-Logged -Exe $ffmpeg -Arguments @(
        '-hide_banner', '-y',
        '-ss', ([string][Math]::Round($timestamp, 3)),
        '-i', $destVideo,
        '-frames:v', '1',
        '-q:v', '2',
        '-vf', 'scale=360:-1',
        '-update', '1',
        (Join-Path $selectedDir $nameForFrame)
    ) -LogPath (Join-Path $workDir ('ffmpeg-selected-{0:D2}.log' -f ($i + 1))) | Out-Null
    $selectedFrames += [ordered]@{
        index = $i + 1
        timestamp_seconds = [Math]::Round($timestamp, 3)
        work_file = $nameForFrame
        contact_sheet_position = [ordered]@{
            row = [int]([Math]::Floor($i / 4) + 1)
            column = [int](($i % 4) + 1)
        }
        ai_instruction = "使用联系表中的第 $($i + 1) 帧，时间约为 $([Math]::Round($timestamp, 2))s。"
    }
}

$frameIndexPath = Join-Path $systemDir 'frame-index.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    source_video = Split-Path -Leaf $destVideo
    contact_sheet = "keyframes-reference-storyboard-contact-sheet-$Name.jpg"
    frame_count = $StoryboardFrames
    selection_method = 'uniform timestamps across source duration'
    frames = $selectedFrames
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $frameIndexPath -Encoding UTF8

$finalSheet = Join-Path $materialDir "keyframes-reference-storyboard-contact-sheet-$Name.jpg"
New-TileSheet -Ffmpeg $ffmpeg `
    -Pattern (Join-Path $selectedDir 'selected-%02d.jpg') `
    -Count $StoryboardFrames `
    -Columns 4 `
    -OutputPath $finalSheet `
    -LogPath (Join-Path $workDir 'ffmpeg-final-sheet.log') | Out-Null

$briefPath = Join-Path $materialDir 'brief.md'
@"
# $Name 参考视频创意任务

## 源视频

- 文件：[original-$Name$extension](original-$Name$extension)
- 视频信息：$([Math]::Round($duration, 2)) 秒，$($videoStream.width)x$($videoStream.height)，$((Parse-Fps $videoStream.r_frame_rate))fps。
- 元数据：[_system-review/video_metadata.json](_system-review/video_metadata.json)

## 已生成素材

- 关键帧联系表：[keyframes-reference-storyboard-contact-sheet-$Name.jpg](keyframes-reference-storyboard-contact-sheet-$Name.jpg)
- 输出目录：[outputs](outputs/)
- 产品信息：[product-brief.md](product-brief.md)

## 产品上下文

在把参考结构映射到你的产品前，请先补全 `product-brief.md`。

## AI 输出要求

- 补写 `outputs/reference-video-storyboard.md`。
- 补写 `outputs/creative-script-directions.md`。
- 第一阶段先产出故事方向池。
- 在方向选定之前，不要创建 production storyboard 或 prompt 文件夹。
"@ | Set-Content -LiteralPath $briefPath -Encoding UTF8

$referencePath = Join-Path $outputsDir 'reference-video-storyboard.md'
@"
# 参考视频分镜拆解

## 关键帧与元数据

- 关键帧联系表：[keyframes-reference-storyboard-contact-sheet-$Name.jpg](../keyframes-reference-storyboard-contact-sheet-$Name.jpg)
- 元数据：[video_metadata.json](../_system-review/video_metadata.json)

## 场景推进

| 顺序 | 代表帧 | 画面内容 | 信息推进 | 可迁移结构 |
| --- | --- | --- | --- | --- |
| 1 | TODO | TODO | TODO | TODO |

## 底层结构

TODO

## 迁移备注

TODO

## 不要直接照搬的内容

TODO
"@ | Set-Content -LiteralPath $referencePath -Encoding UTF8

$directionsPath = Join-Path $outputsDir 'creative-script-directions.md'
@"
# 创意脚本方向

## 前提假设

TODO

## 方向总览

| 方向 | 核心 hook | 用户欲望 | 要测试什么 | 风险 |
| --- | --- | --- | --- | --- |
| 1 | TODO | TODO | TODO | TODO |

## 方向 1

### 核心假设

TODO

### Hook

TODO

### 故事前提

TODO

### 冲突与触发

TODO

### 产品承接

TODO

### 产品映射

请参考 `../product-brief.md`。如果其中仍然包含 TODO，或缺少产品特定信息，请列出缺失问题，并将产品映射标记为待补充。

### 可扩展变体

TODO

### 待测试指标

TODO

### 需要人工判断的问题

TODO
"@ | Set-Content -LiteralPath $directionsPath -Encoding UTF8

$aiInputPackPath = Join-Path $systemDir 'ai-input-pack.md'
@"
# AI 输入包：$Name

请先阅读此文件，再查看关键帧联系表和 frame-index。

## 路径

- 素材文件夹：$materialDir
- 源视频：$destVideo
- 关键帧联系表：$finalSheet
- 帧索引：$frameIndexPath
- 参考分镜：$referencePath
- 创意方向：$directionsPath
- 产品信息：$productBriefOutputPath

## 视频信息

- 时长：$([Math]::Round($duration, 2)) 秒
- 尺寸：$($videoStream.width)x$($videoStream.height)
- FPS：$((Parse-Fps $videoStream.r_frame_rate))
- 选帧数量：$StoryboardFrames

## 第一阶段规则

- 补写 reference-video-storyboard.md。
- 补写 creative-script-directions.md。
- 做产品映射时请使用 product-brief.md。
- 如果 product-brief.md 仍包含 TODO，或缺少产品特定信息，不要编造产品事实；输出缺失问题，并把产品映射保持为待补充状态。
- 只创建故事方向池。
- 在用户选择方向之前，不要创建 production scripts 或 prompts。
"@ | Set-Content -LiteralPath $aiInputPackPath -Encoding UTF8

$manifestPath = Join-Path $systemDir 'run-manifest.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    script = $PSCommandPath
    material_folder = $materialDir
    video = $destVideo
    metadata = $metadataPath
    frame_index = $frameIndexPath
    final_storyboard_sheet = $finalSheet
    ai_input_pack = $aiInputPackPath
    brief = $briefPath
    product_brief = $productBriefOutputPath
    outputs = @($referencePath, $directionsPath)
    temp_work_dir_kept = [bool]$KeepWork
    frame_counts = [ordered]@{
        selected = $StoryboardFrames
        uniform = @(Get-ChildItem -LiteralPath $uniformDir -Filter '*.jpg').Count
        scene = @(Get-ChildItem -LiteralPath $sceneDir -Filter '*.jpg').Count
    }
    next_ai_inputs = @(
        '先阅读 _system-review/ai-input-pack.md。',
        '查看一次 final_storyboard_sheet。',
        '使用 _system-review/frame-index.json 获取时间戳和联系表位置。',
        '用 AI 分析替换 outputs 中的骨架文案。'
    )
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

if (-not $KeepWork) {
    $rootResolved = Resolve-Path -LiteralPath $materialDir
    $workResolved = Resolve-Path -LiteralPath $workDir
    if (-not $workResolved.Path.StartsWith($rootResolved.Path)) {
        throw "Refusing to delete work dir outside material folder: $($workResolved.Path)"
    }
    Remove-Item -LiteralPath $workResolved.Path -Recurse -Force
}

[ordered]@{
    material_folder = $materialDir
    ai_input_pack = $aiInputPackPath
    final_storyboard_sheet = $finalSheet
    frame_index = $frameIndexPath
    brief = $briefPath
    product_brief = $productBriefOutputPath
    reference_storyboard = $referencePath
    creative_directions = $directionsPath
    manifest = $manifestPath
} | ConvertTo-Json -Depth 4
