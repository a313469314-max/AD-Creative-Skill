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

    [string]$ProductId,

    [string]$ProductProfileDir,

    [switch]$Copy,

    [switch]$Move,

    [switch]$KeepWork,

    [int]$StoryboardFrames = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'product-context.ps1')
. (Join-Path $PSScriptRoot 'lib\common.ps1')
. (Join-Path $PSScriptRoot 'lib\template-utils.ps1')

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
$skillRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') -ErrorAction SilentlyContinue
$skillRootPath = if ($skillRoot) { $skillRoot.Path } else { Split-Path -Parent $PSScriptRoot }
$methodologyPath = Join-Path $skillRootPath 'methodology\ad-creative-methodology.md'
$fullMethodologyIndexPath = Join-Path $skillRootPath 'methodology\full\README.md'
$productContext = Resolve-ProductContext -SkillRoot $skillRootPath -ProductId $ProductId -ProductProfileDir $ProductProfileDir
$productContextMarkdown = New-ProductContextMarkdown -ProductContext $productContext

$productBriefOutputPath = Join-Path $materialDir 'product-brief.md'
if (-not [string]::IsNullOrWhiteSpace($ProductBriefPath)) {
    $resolvedProductBrief = Resolve-FilePath $ProductBriefPath
    Copy-Item -LiteralPath $resolvedProductBrief -Destination $productBriefOutputPath
} else {
    Write-TemplateFile `
        -TemplatePath (Join-Path $skillRootPath 'templates\mix\product-brief.md') `
        -OutputPath $productBriefOutputPath
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
- 方法库：$methodologyPath
- 全文方法论索引：$fullMethodologyIndexPath

## 产品目录

$productContextMarkdown

## 共用创意方向

TODO：描述这组视频共享的 hook、主题或创意方向。

## 产品映射上下文

在把这个共享方向映射到你的产品前，请先补全 `product-brief.md`。

## AI 输出要求

- 先阅读方法库，说明采用方法、排除方法、承接桥、产品证明和触发机制。
- 需要更细方法解释或案例机制时，再查阅全文方法论索引。
- 把这些视频当作同一个方向级任务，汇总共同机制和差异点。
- 第一阶段只输出故事方向池，不创建 production storyboard、prompt 或 script-* 文件夹。
"@ | Set-Content -LiteralPath $briefPath -Encoding UTF8

$sharedPath = Join-Path $outputsDir 'shared-analysis-mix.md'
@"
# 汇总分析

请先阅读方法库：$methodologyPath

## 方法论调用记录

| 项目 | 结论 |
| --- | --- |
| 本次调用的产品上下文 | TODO |
| 主要诊断问题 | TODO |
| 采用方法 | TODO |
| 排除方法及原因 | TODO |
| Phase1 边界确认 | 只输出候选故事方向，不创建 production storyboard、prompt 或 script-* 文件夹。 |

## 产品上下文适配

$productContextMarkdown

| 方向/机制 | 产品适配度 | 题材与美术适配 | 可承接机制 | 可用资产 | 视觉记忆点 | 历史素材依据 | 主要缺口 | 建议优先级 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO |

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

## 共同机制

| 机制 | 共同表现 | 对应方法 | 可迁移价值 | 风险 |
| --- | --- | --- | --- | --- |
| 共享 hook | TODO | TODO | TODO | TODO |
| 承接桥 | TODO | TODO | TODO | TODO |
| 产品证明 | TODO | TODO | TODO | TODO |
| 触发机制 | TODO | TODO | TODO | TODO |
| 剪辑节奏 | TODO | TODO | TODO | TODO |

## 视频差异点

| 视频 | 表层差异 | 底层结构差异 | 情绪差异 | 可学习点 |
| --- | --- | --- | --- | --- |
| TODO | TODO | TODO | TODO | TODO |

## 可迁移结构

| 可迁移结构 | 来自哪些视频 | 适配原因 | 需要产品信息 | 不可照搬点 |
| --- | --- | --- | --- | --- |
| TODO | TODO | TODO | TODO | TODO |

## 方法匹配

| 方法 | 适配度 | 支持证据 | 排除或限制原因 |
| --- | --- | --- | --- |
| TODO | TODO | TODO | TODO |

## 产品映射

请参考 `../product-brief.md`。如果其中仍然包含 TODO，或缺少产品特定信息，请列出缺失问题，并将产品映射标记为待补充。

| 映射项 | 当前判断 | 缺失信息 | 风险 |
| --- | --- | --- | --- |
| 题材与美术 | TODO | TODO | TODO |
| UI 质感与特效反馈 | TODO | TODO | TODO |
| 视觉记忆点 | TODO | TODO | TODO |
| 承接桥 | TODO | TODO | TODO |
| 产品证明 | TODO | TODO | TODO |
| 目标用户信号 | TODO | TODO | TODO |
| 测试指标 | TODO | TODO | TODO |

## 创意方向池优先级

| 方向 | 优先级 | 采用方法 | 排除方法 | 共享 hook | 可迁移结构 | 承接桥 | 产品证明 | 触发机制 | 目标用户信号 | 测试指标 | 风险 | 人工判断点 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO | TODO |
"@ | Set-Content -LiteralPath $sharedPath -Encoding UTF8

$aiPackPath = Join-Path $systemDir 'ai-input-pack.md'
@"
# AI 输入包：$Name

这是一个同方向的多视频批次。

## 文件

- 方法库：$methodologyPath
- 全文方法论索引：$fullMethodologyIndexPath
- 方法库相对路径：methodology/ad-creative-methodology.md
- 全文方法论相对路径：methodology/full/README.md
- 任务说明：$briefPath
- 汇总分析：$sharedPath
- 产品信息：$productBriefOutputPath
- 帧索引：$(Join-Path $systemDir 'frame-index.json')
- 元数据：$(Join-Path $systemDir 'video_metadata.json')

## 可选产品目录

$productContextMarkdown

## 当前产品录屏上下文

如果本次对话另附当前产品真实游戏录屏，请把它作为本次任务局部的产品依据来分析；如果需要落盘，只能放进该游戏自己的 products/<product-id>/recordings/，不要影响其他游戏或其他素材分析。

当前产品录屏必须分析核心玩法体验链路、首个可验证体验、首个爽点或关键反馈出现时间、题材与美术、UI 质感、技能/特效反馈、视觉记忆点、可广告化视觉资产、真实可承接 hook 和不可编造边界。

## 规则

请先阅读方法库，按素材缺口选择采用方法和排除方法。
全文方法论仅用于按需补充解释、方法细节、案例机制或未来 Phase2 设计，不能覆盖 Phase1 边界。
如果提供了产品目录，必须先以 product-profile 和 gameplay-systems 作为产品事实，再用 hook-mapping、asset-inventory、recordings、当前产品 materials/memory、根级 competitors 模块和 playbooks 做适配判断。
广告表达形式、素材结构、测试优先级或创意方向池不能只根据当前产品录屏得出；必须同时结合当前产品具体素材和同玩法竞品素材。竞品素材只能放在根级 competitors/ 模块，不能放进 products/<product-id>/。
如果本次对话另附当前产品真实游戏录屏，题材与美术分析是必做项：题材类型、世界观内容壳、美术风格、角色/单位卖相、敌人/Boss 卖相、场景卖相、UI 质感、技能/特效反馈、视觉记忆点、可广告化视觉资产和不适合作为广告开头的画面都必须进入判断；该录屏分析只用于本次产品判断。
请把这些视频当作一个方向级创意任务来分析，不要拆分成多个独立的 single 视频文件夹。
做产品映射时请使用 product-brief.md。如果产品信息缺失，不要编造产品事实；输出缺失问题，并把产品映射保持为待补充状态。
Phase1 只输出候选故事方向，不要创建 production storyboard、prompt、出图内容或 script-* 文件夹。
"@ | Set-Content -LiteralPath $aiPackPath -Encoding UTF8

$mixTemplateVars = @{
    Name = $Name
    SourceVideoList = (($metadataItems | ForEach-Object { "- 视频 $($_.index)：$($_.file)，$($_.duration_seconds)s，$($_.width)x$($_.height)" }) -join "`r`n")
    MethodologyPath = $methodologyPath
    FullMethodologyIndexPath = $fullMethodologyIndexPath
    ProductContextMarkdown = $productContextMarkdown
    BriefPath = $briefPath
    SharedPath = $sharedPath
    ProductBriefOutputPath = $productBriefOutputPath
    FrameIndexPath = Join-Path $systemDir 'frame-index.json'
    MetadataPath = Join-Path $systemDir 'video_metadata.json'
}
foreach ($templateSpec in @(
    @{ Template = 'brief.md'; Output = $briefPath },
    @{ Template = 'shared-analysis-mix.md'; Output = $sharedPath },
    @{ Template = 'ai-input-pack.md'; Output = $aiPackPath }
)) {
    Write-TemplateFile `
        -TemplatePath (Join-Path $skillRootPath "templates\mix\$($templateSpec.Template)") `
        -OutputPath $templateSpec.Output `
        -Variables $mixTemplateVars
}

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
    product_context = if ($productContext.Enabled) {
        [ordered]@{
            product_id = $productContext.ProductId
            profile_dir = $productContext.ProfileDir
            files = $productContext.Files
        }
    } else {
        $null
    }
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
    check_status = $checkResult.status
    check_errors = $checkResult.errors
    check_warnings = $checkResult.warnings
    check_content_placeholders_remaining = $checkResult.content_placeholders_remaining
    check_placeholder_warnings = $checkResult.placeholder_warnings
} | ConvertTo-Json -Depth 6

if ($checkExit -ne 0) {
    exit $checkExit
}
