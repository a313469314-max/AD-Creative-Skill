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

    [double]$SceneThreshold = 0.23
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'product-context.ps1')
. (Join-Path $PSScriptRoot 'lib\common.ps1')
. (Join-Path $PSScriptRoot 'lib\template-utils.ps1')

function Assert-SafeFileNamePart {
    param([string]$Value, [string]$FieldName)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$FieldName cannot be empty."
    }
    if ($Value -match '[\\/:*?"<>|]') {
        throw "$FieldName contains invalid filename characters: $Value"
    }
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
$skillRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') -ErrorAction SilentlyContinue
$skillRootPath = if ($skillRoot) { $skillRoot.Path } else { Split-Path -Parent $PSScriptRoot }
$methodologyPath = Join-Path $skillRootPath 'methodology\ad-creative-methodology.md'
$fullMethodologyIndexPath = Join-Path $skillRootPath 'methodology\full\README.md'
$productContext = Resolve-ProductContext -SkillRoot $skillRootPath -ProductId $ProductId -ProductProfileDir $ProductProfileDir
$productContextMarkdown = New-ProductContextMarkdown -ProductContext $productContext

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
    Write-TemplateFile `
        -TemplatePath (Join-Path $skillRootPath 'templates\reference\product-brief.md') `
        -OutputPath $productBriefOutputPath
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
- 方法库：$methodologyPath
- 全文方法论索引：$fullMethodologyIndexPath

## 产品目录

$productContextMarkdown

## 产品上下文

在把参考结构映射到你的产品前，请先补全 `product-brief.md`。

## AI 输出要求

- 先阅读方法库，说明采用方法、排除方法、承接桥、产品证明和触发机制。
- 需要更细方法解释或案例机制时，再查阅全文方法论索引。
- 补写 `outputs/reference-video-storyboard.md`。
- 补写 `outputs/creative-script-directions.md`。
- `outputs/reference-video-storyboard.md` 只拆解原参考视频，不是给用户产品制作新的 production storyboard。
- 第一阶段先产出故事方向池。
- 在方向选定之前，不要创建 production storyboard 或 prompt 文件夹。
"@ | Set-Content -LiteralPath $briefPath -Encoding UTF8

$referencePath = Join-Path $outputsDir 'reference-video-storyboard.md'
@"
# 参考视频分镜拆解

此文件只拆解原参考视频的场景变化、底层结构和可迁移机制，不是用户产品的 production storyboard。

## 关键帧与元数据

- 关键帧联系表：[keyframes-reference-storyboard-contact-sheet-$Name.jpg](../keyframes-reference-storyboard-contact-sheet-$Name.jpg)
- 元数据：[video_metadata.json](../_system-review/video_metadata.json)
- 方法库：$methodologyPath

## 方法论诊断

| 项目 | 结论 |
| --- | --- |
| 本次调用的产品上下文 | TODO |
| 主要诊断问题 | TODO |
| 采用方法 | TODO |
| 排除方法及原因 | TODO |
| 承接桥判断 | TODO |
| 产品证明判断 | TODO |
| 素材定位判断 | TODO |
| 触发机制判断 | TODO |

## 场景推进

| 时间/代表帧 | 表层画面 | 底层结构 | 钩子机制 | 冲突压力 | 剪辑节奏 | 可迁移点 | 不可照搬点 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO |

## 底层结构

| 结构层 | 观察 | 是否可迁移 | 迁移条件 |
| --- | --- | --- | --- |
| 注意力入口 | TODO | TODO | TODO |
| 冲突推进 | TODO | TODO | TODO |
| 关键变化 | TODO | TODO | TODO |
| 情绪 payoff | TODO | TODO | TODO |
| 产品证明 | TODO | TODO | TODO |

## 迁移备注

| 可迁移结构 | 适配原因 | 需要产品信息 | 风险 |
| --- | --- | --- | --- |
| TODO | TODO | TODO | TODO |

## 不要直接照搬的内容

| 表层元素 | 不建议照搬原因 | 可替代的底层机制 |
| --- | --- | --- |
| TODO | TODO | TODO |
"@ | Set-Content -LiteralPath $referencePath -Encoding UTF8

$directionsPath = Join-Path $outputsDir 'creative-script-directions.md'
@"
# 创意脚本方向

请先阅读方法库：$methodologyPath

## 方法论调用记录

| 项目 | 结论 |
| --- | --- |
| 本次调用的产品上下文 | TODO |
| 主要诊断问题 | TODO |
| 采用方法 | TODO |
| 排除方法及原因 | TODO |
| Phase1 边界确认 | 只输出候选故事方向，不创建 production storyboard、prompt 或 script-* 文件夹。 |

## 前提假设

TODO

## 产品上下文适配

$productContextMarkdown

| 方向 | 产品适配度 | 题材与美术适配 | 可承接机制 | 可用资产 | 视觉记忆点 | 历史素材依据 | 主要缺口 | 建议优先级 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO |

### 题材与美术适配（真实录屏必填）

如果本次任务附带当前产品的真实游戏录屏，本节必须填写，不可只停留在玩法机制判断。录屏分析默认只服务于本次产品判断，不自动写入产品增强包，也不影响其他游戏或其他素材分析。

| 项目 | 当前观察 | 广告承接价值 | 风险/限制 |
| --- | --- | --- | --- |
| 题材类型 | TODO | TODO | TODO |
| 世界观内容壳 | TODO | TODO | TODO |
| 美术风格 | TODO | TODO | TODO |
| 角色/单位卖相 | TODO | TODO | TODO |
| 场景卖相 | TODO | TODO | TODO |
| UI 质感 | TODO | TODO | TODO |
| 技能/特效反馈 | TODO | TODO | TODO |
| 视觉记忆点 | TODO | TODO | TODO |
| 可广告化视觉资产 | TODO | TODO | TODO |
| 不适合作为广告开头的画面 | TODO | TODO | TODO |

## 方向总览

| 方向 | 优先级 | 采用方法 | 排除方法 | 核心 hook | 承接桥 | 产品证明 | 触发机制 | 目标用户信号 | 测试指标 | 风险 | 人工判断点 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO |

## 方向 1

### 核心假设

TODO

### 采用方法与排除方法

| 类型 | 方法 | 理由 |
| --- | --- | --- |
| 主方法 | TODO | TODO |
| 辅助方法 | TODO | TODO |
| 排除方法 | TODO | TODO |

### Hook

TODO

### 故事前提

TODO

### 冲突与触发

TODO

### 承接桥与产品证明

| 项目 | 内容 |
| --- | --- |
| 承接桥 | TODO |
| 产品证明 | TODO |
| 触发机制 | TODO |
| 可见反馈 | TODO |
| 素材定位 | TODO |

### 产品承接

TODO

### 产品映射

请参考 `../product-brief.md`。如果其中仍然包含 TODO，或缺少产品特定信息，请列出缺失问题，并将产品映射标记为待补充。

### 产品专属适配评分

| 项目 | 判断 |
| --- | --- |
| 产品适配度 | TODO |
| 题材与美术适配 | TODO |
| 可承接机制 | TODO |
| 可用资产 | TODO |
| UI 质感与特效反馈 | TODO |
| 视觉记忆点 | TODO |
| 历史素材依据 | TODO |
| 主要缺口 | TODO |
| 是否需要替代表达 | TODO |

### 目标用户信号

| 信号 | 画面或机制 | 预期筛选作用 |
| --- | --- | --- |
| TODO | TODO | TODO |

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

- 方法库：$methodologyPath
- 全文方法论索引：$fullMethodologyIndexPath
- 方法库相对路径：methodology/ad-creative-methodology.md
- 全文方法论相对路径：methodology/full/README.md
- 素材文件夹：$materialDir
- 源视频：$destVideo
- 关键帧联系表：$finalSheet
- 帧索引：$frameIndexPath
- 参考分镜：$referencePath
- 创意方向：$directionsPath
- 产品信息：$productBriefOutputPath

## 可选产品目录

$productContextMarkdown

## 当前产品录屏上下文

如果本次对话另附当前产品真实游戏录屏，请把它作为本次任务局部的产品依据来分析；如果需要落盘，只能放进该游戏自己的 products/<product-id>/recordings/，不要影响其他游戏或其他素材分析。

当前产品录屏必须分析核心玩法体验链路、首个可验证体验、首个爽点或关键反馈出现时间、题材与美术、UI 质感、技能/特效反馈、视觉记忆点、可广告化视觉资产、真实可承接 hook 和不可编造边界。

## 视频信息

- 时长：$([Math]::Round($duration, 2)) 秒
- 尺寸：$($videoStream.width)x$($videoStream.height)
- FPS：$((Parse-Fps $videoStream.r_frame_rate))
- 选帧数量：$StoryboardFrames

## 第一阶段规则

- 先阅读方法库，按素材缺口选择采用方法和排除方法。
- 全文方法论仅用于按需补充解释、方法细节、案例机制或未来 Phase2 设计，不能覆盖 Phase1 边界。
- 如果提供了产品目录，必须先以 product-profile 和 gameplay-systems 作为产品事实，再用 hook-mapping、asset-inventory、recordings、当前产品 materials/memory、根级 competitors 模块和 playbooks 做适配判断。
- 广告表达形式、素材结构、测试优先级或创意方向池不能只根据当前产品录屏得出；必须同时结合当前产品具体素材和同玩法竞品素材。竞品素材只能放在根级 competitors/ 模块，不能放进 products/<product-id>/。
- 如果本次对话另附当前产品真实游戏录屏，题材与美术分析是必做项：题材类型、世界观内容壳、美术风格、角色/单位卖相、敌人/Boss 卖相、场景卖相、UI 质感、技能/特效反馈、视觉记忆点、可广告化视觉资产和不适合作为广告开头的画面都必须进入判断；该录屏分析只用于本次产品判断。
- 补写 reference-video-storyboard.md。
- 补写 creative-script-directions.md。
- reference-video-storyboard.md 只拆解原参考视频，不是 production storyboard。
- 做产品映射时请使用 product-brief.md。
- 如果 product-brief.md 仍包含 TODO，或缺少产品特定信息，不要编造产品事实；输出缺失问题，并把产品映射保持为待补充状态。
- 只创建故事方向池。
- 在用户选择方向之前，不要创建 production storyboard、production scripts、prompts 或 script-* 文件夹。
"@ | Set-Content -LiteralPath $aiInputPackPath -Encoding UTF8

$referenceTemplateVars = @{
    Name = $Name
    Extension = $extension
    DurationRounded = [Math]::Round($duration, 2)
    Width = $videoStream.width
    Height = $videoStream.height
    Fps = Parse-Fps $videoStream.r_frame_rate
    StoryboardFrames = $StoryboardFrames
    MethodologyPath = $methodologyPath
    FullMethodologyIndexPath = $fullMethodologyIndexPath
    ProductContextMarkdown = $productContextMarkdown
    MaterialDir = $materialDir
    DestVideo = $destVideo
    FinalSheet = $finalSheet
    FrameIndexPath = $frameIndexPath
    ReferencePath = $referencePath
    DirectionsPath = $directionsPath
    ProductBriefOutputPath = $productBriefOutputPath
}
foreach ($templateSpec in @(
    @{ Template = 'brief.md'; Output = $briefPath },
    @{ Template = 'reference-video-storyboard.md'; Output = $referencePath },
    @{ Template = 'creative-script-directions.md'; Output = $directionsPath },
    @{ Template = 'ai-input-pack.md'; Output = $aiInputPackPath }
)) {
    Write-TemplateFile `
        -TemplatePath (Join-Path $skillRootPath "templates\reference\$($templateSpec.Template)") `
        -OutputPath $templateSpec.Output `
        -Variables $referenceTemplateVars
}

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
    product_context = if ($productContext.Enabled) {
        [ordered]@{
            product_id = $productContext.ProductId
            profile_dir = $productContext.ProfileDir
            files = $productContext.Files
        }
    } else {
        $null
    }
    temp_work_dir_kept = [bool]$KeepWork
    frame_counts = [ordered]@{
        selected = $StoryboardFrames
        uniform = @(Get-ChildItem -LiteralPath $uniformDir -Filter '*.jpg').Count
        scene = @(Get-ChildItem -LiteralPath $sceneDir -Filter '*.jpg').Count
    }
    next_ai_inputs = @(
        '先阅读 methodology/ad-creative-methodology.md。',
        '需要更细方法解释时再查阅 methodology/full/README.md。',
        '先阅读 _system-review/ai-input-pack.md。',
        '如果提供了产品目录，按产品事实优先级判断方向适配度。',
        '查看一次 final_storyboard_sheet。',
        '使用 _system-review/frame-index.json 获取时间戳和联系表位置。',
        '用 AI 分析替换 outputs 中的骨架文案，并说明采用方法、排除方法、承接桥、产品证明和触发机制。'
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
    product_context = if ($productContext.Enabled) {
        [ordered]@{
            product_id = $productContext.ProductId
            profile_dir = $productContext.ProfileDir
            files = $productContext.Files
        }
    } else {
        $null
    }
} | ConvertTo-Json -Depth 4
