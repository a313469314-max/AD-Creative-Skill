param(
    [Parameter(Mandatory = $true)]
    [string]$RecordingDir,

    [string]$SourceVideoPath,

    [string]$FfmpegPath,

    [string]$FfprobePath,

    [int]$FrameCount = 24,

    [int]$Columns = 4,

    [int]$DetailFrameWidth = 360,

    [int]$ReviewFrameWidth = 180,

    [int]$ReviewJpegQuality = 7,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\common.ps1')
. (Join-Path $PSScriptRoot 'lib\template-utils.ps1')

if ($FrameCount -lt 4 -or $FrameCount -gt 60) {
    throw 'FrameCount must be between 4 and 60.'
}
if ($Columns -lt 2 -or $Columns -gt 8) {
    throw 'Columns must be between 2 and 8.'
}
if ($DetailFrameWidth -lt 120 -or $DetailFrameWidth -gt 720) {
    throw 'DetailFrameWidth must be between 120 and 720.'
}
if ($ReviewFrameWidth -lt 96 -or $ReviewFrameWidth -gt 360) {
    throw 'ReviewFrameWidth must be between 96 and 360.'
}
if ($ReviewFrameWidth -gt $DetailFrameWidth) {
    throw 'ReviewFrameWidth must be less than or equal to DetailFrameWidth.'
}
if ($ReviewJpegQuality -lt 2 -or $ReviewJpegQuality -gt 31) {
    throw 'ReviewJpegQuality must be between 2 and 31.'
}

$recordingRoot = Resolve-Path -LiteralPath $RecordingDir -ErrorAction SilentlyContinue
if (-not $recordingRoot) {
    throw "RecordingDir not found: $RecordingDir"
}
$recordingRootPath = $recordingRoot.Path
$sourceDir = Join-Path $recordingRootPath 'source'
if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
    throw "Missing source directory: $sourceDir"
}

$ffmpeg = Resolve-Executable -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
$ffprobe = Resolve-Executable -ExplicitPath $FfprobePath -CommandName 'ffprobe'

if (-not [string]::IsNullOrWhiteSpace($SourceVideoPath)) {
    $sourceVideo = Resolve-FilePath $SourceVideoPath
} else {
    $videoFiles = @(Get-ChildItem -LiteralPath $sourceDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension.ToLowerInvariant() -in @('.mp4', '.mov', '.mkv', '.webm', '.avi', '.m4v')
    })
    if ($videoFiles.Count -eq 0) {
        throw "No supported video file found under source directory: $sourceDir"
    }
    if ($videoFiles.Count -gt 1) {
        $names = ($videoFiles | ForEach-Object { $_.FullName }) -join '; '
        throw "More than one video file found. Pass -SourceVideoPath to process exactly one file. Found: $names"
    }
    $sourceVideo = $videoFiles[0].FullName
}

$sourceResolved = Resolve-Path -LiteralPath $sourceVideo
$sourceVideo = $sourceResolved.Path
$sourceDirResolved = Resolve-Path -LiteralPath $sourceDir
if (-not $sourceVideo.StartsWith($sourceDirResolved.Path)) {
    throw "Source video must be inside the recording source directory: $sourceDir"
}

$evidenceDir = Join-Path $recordingRootPath 'evidence'
$framesRoot = Join-Path $evidenceDir 'frames'
$reviewDir = Join-Path $evidenceDir 'review'
$reviewFramesRoot = Join-Path $reviewDir 'frames'
$clipsDir = Join-Path $evidenceDir 'clips'
$systemDir = Join-Path $recordingRootPath '_system-review'
$logsDir = Join-Path $systemDir 'logs'
New-Item -ItemType Directory -Path $evidenceDir, $framesRoot, $clipsDir, $systemDir, $logsDir -Force | Out-Null

$sourceBaseName = [IO.Path]::GetFileNameWithoutExtension($sourceVideo)
$sourceSlug = New-SafeSlug $sourceBaseName
$framesDir = Join-Path $framesRoot $sourceSlug
$reviewFramesDir = Join-Path $reviewFramesRoot $sourceSlug

if ($Force) {
    $rootResolved = Resolve-Path -LiteralPath $recordingRootPath
    $framesRootResolved = Resolve-Path -LiteralPath $framesRoot
    if (-not $framesRootResolved.Path.StartsWith($rootResolved.Path)) {
        throw "Refusing to remove frames outside recording directory: $($framesRootResolved.Path)"
    }
    Get-ChildItem -LiteralPath $framesRootResolved.Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    if (Test-Path -LiteralPath $reviewDir) {
        $reviewDirResolved = Resolve-Path -LiteralPath $reviewDir
        if (-not $reviewDirResolved.Path.StartsWith($rootResolved.Path)) {
            throw "Refusing to remove review evidence outside recording directory: $($reviewDirResolved.Path)"
        }
        Remove-Item -LiteralPath $reviewDirResolved.Path -Recurse -Force
    }
    foreach ($fileName in @('contact-sheet.jpg')) {
        $path = Join-Path $evidenceDir $fileName
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}
New-Item -ItemType Directory -Path $framesDir, $reviewFramesDir -Force | Out-Null

$probeJson = & $ffprobe @('-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', $sourceVideo) | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "ffprobe failed for video file: $sourceVideo"
}
$probe = $probeJson | ConvertFrom-Json
$videoStreams = @($probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1)
if ($videoStreams.Count -eq 0) {
    throw "No video stream found in input file: $sourceVideo. The file may be audio-only, corrupted, or unsupported."
}
$videoStream = $videoStreams[0]
$audioStreams = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1)
$audioStream = if ($audioStreams.Count -gt 0) { $audioStreams[0] } else { $null }

$duration = Convert-ToNullableDouble $videoStream.duration
if ($null -eq $duration -and $probe.format.duration) {
    $duration = Convert-ToNullableDouble $probe.format.duration
}
if ($null -eq $duration -or $duration -le 0) {
    throw "Cannot determine a valid video duration for input file: $sourceVideo"
}

$metadataPath = Join-Path $systemDir 'video_metadata.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    mode = 'product-recording'
    recording_root = $recordingRootPath
    source_video = $sourceVideo
    source_video_relative = Get-RelativePath -BasePath $recordingRootPath -FullPath $sourceVideo
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

$selectedFrames = @()
$startTime = 0.03
$endTime = [Math]::Max($startTime, $duration - 0.35)
$detailScaleFilter = New-ScaleFilter -Width $DetailFrameWidth
$reviewScaleFilter = New-ScaleFilter -Width $ReviewFrameWidth
for ($i = 0; $i -lt $FrameCount; $i++) {
    $ratio = if ($FrameCount -eq 1) { 0 } else { $i / ($FrameCount - 1) }
    $timestamp = $startTime + (($endTime - $startTime) * $ratio)
    $frameName = 'frame-{0:D3}.jpg' -f ($i + 1)
    $framePath = Join-Path $framesDir $frameName
    Invoke-Logged -Exe $ffmpeg -Arguments @(
        '-hide_banner', '-y',
        '-ss', ([string][Math]::Round($timestamp, 3)),
        '-i', $sourceVideo,
        '-frames:v', '1',
        '-q:v', '2',
        '-vf', $detailScaleFilter,
        '-update', '1',
        $framePath
    ) -LogPath (Join-Path $logsDir ('ffmpeg-frame-{0:D3}.log' -f ($i + 1))) | Out-Null

    $reviewFramePath = Join-Path $reviewFramesDir $frameName
    Invoke-Logged -Exe $ffmpeg -Arguments @(
        '-hide_banner', '-y',
        '-i', $framePath,
        '-frames:v', '1',
        '-q:v', ([string]$ReviewJpegQuality),
        '-vf', $reviewScaleFilter,
        '-update', '1',
        $reviewFramePath
    ) -LogPath (Join-Path $logsDir ('ffmpeg-review-frame-{0:D3}.log' -f ($i + 1))) | Out-Null

    $selectedFrames += [ordered]@{
        index = $i + 1
        timestamp_seconds = [Math]::Round($timestamp, 3)
        timestamp_label = Format-TimestampLabel $timestamp
        file = $framePath
        relative_file = Get-RelativePath -BasePath $recordingRootPath -FullPath $framePath
        review_file = $reviewFramePath
        review_relative_file = Get-RelativePath -BasePath $recordingRootPath -FullPath $reviewFramePath
        contact_sheet_position = [ordered]@{
            row = [int]([Math]::Floor($i / $Columns) + 1)
            column = [int](($i % $Columns) + 1)
        }
    }
}

$rows = [Math]::Ceiling($FrameCount / $Columns)
$contactSheetPath = Join-Path $evidenceDir 'contact-sheet.jpg'
Invoke-Logged -Exe $ffmpeg -Arguments @(
    '-hide_banner', '-y',
    '-framerate', '1',
    '-i', (Join-Path $framesDir 'frame-%03d.jpg'),
    '-vf', "tile=${Columns}x${rows}:padding=4:margin=2",
    '-frames:v', '1',
    $contactSheetPath
) -LogPath (Join-Path $logsDir 'ffmpeg-contact-sheet.log') | Out-Null

$reviewContactSheetPath = Join-Path $reviewDir 'contact-sheet.jpg'
Invoke-Logged -Exe $ffmpeg -Arguments @(
    '-hide_banner', '-y',
    '-framerate', '1',
    '-i', (Join-Path $reviewFramesDir 'frame-%03d.jpg'),
    '-vf', "tile=${Columns}x${rows}:padding=4:margin=2",
    '-frames:v', '1',
    '-q:v', ([string]$ReviewJpegQuality),
    $reviewContactSheetPath
) -LogPath (Join-Path $logsDir 'ffmpeg-review-contact-sheet.log') | Out-Null

$frameIndexPath = Join-Path $systemDir 'frame-index.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    mode = 'product-recording'
    recording_root = $recordingRootPath
    source_video = $sourceVideo
    contact_sheet = Get-RelativePath -BasePath $recordingRootPath -FullPath $contactSheetPath
    review_contact_sheet = Get-RelativePath -BasePath $recordingRootPath -FullPath $reviewContactSheetPath
    frames_dir = Get-RelativePath -BasePath $recordingRootPath -FullPath $framesDir
    review_frames_dir = Get-RelativePath -BasePath $recordingRootPath -FullPath $reviewFramesDir
    frame_count = $FrameCount
    columns = $Columns
    detail_frame_width = $DetailFrameWidth
    review_frame_width = $ReviewFrameWidth
    review_jpeg_quality = $ReviewJpegQuality
    selection_method = 'uniform timestamps across source duration'
    frames = $selectedFrames
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $frameIndexPath -Encoding UTF8

$aiInputPackPath = Join-Path $systemDir 'ai-input-pack.md'
$sourceNotesPath = Join-Path $recordingRootPath 'source-notes.md'
$analysisPath = Join-Path $recordingRootPath 'recording-analysis.md'
$recordingTemplateVars = @{
    RecordingRootPath = $recordingRootPath
    SourceVideo = $sourceVideo
    MetadataPath = $metadataPath
    FrameIndexPath = $frameIndexPath
    ReviewContactSheetPath = $reviewContactSheetPath
    ReviewFramesDir = $reviewFramesDir
    ContactSheetPath = $contactSheetPath
    FramesDir = $framesDir
    SourceNotesPath = $sourceNotesPath
    AnalysisPath = $analysisPath
    DurationSeconds = [Math]::Round($duration, 3)
}
Write-TemplateFile `
    -TemplatePath (Join-Path $PSScriptRoot '..\templates\recording\ai-input-pack.md') `
    -OutputPath $aiInputPackPath `
    -Variables $recordingTemplateVars

if (-not (Test-Path -LiteralPath $sourceNotesPath -PathType Leaf)) {
    Write-TemplateFile `
        -TemplatePath (Join-Path $PSScriptRoot '..\templates\recording\source-notes.md') `
        -OutputPath $sourceNotesPath `
        -Variables $recordingTemplateVars
}

if (-not (Test-Path -LiteralPath $analysisPath -PathType Leaf)) {
    Write-TemplateFile `
        -TemplatePath (Join-Path $PSScriptRoot '..\templates\recording\recording-analysis.md') `
        -OutputPath $analysisPath `
        -Variables $recordingTemplateVars
}

$manifestPath = Join-Path $systemDir 'run-manifest.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    script = $PSCommandPath
    mode = 'product-recording'
    recording_root = $recordingRootPath
    source_video = $sourceVideo
    metadata = $metadataPath
    frame_index = $frameIndexPath
    review_contact_sheet = $reviewContactSheetPath
    review_frames_dir = $reviewFramesDir
    detail_contact_sheet = $contactSheetPath
    detail_frames_dir = $framesDir
    ai_input_pack = $aiInputPackPath
    source_notes = $sourceNotesPath
    recording_analysis = $analysisPath
    frame_count = $FrameCount
    columns = $Columns
    detail_frame_width = $DetailFrameWidth
    review_frame_width = $ReviewFrameWidth
    review_jpeg_quality = $ReviewJpegQuality
    next_ai_inputs = @(
        'Read _system-review/ai-input-pack.md.',
        'Open evidence/review/contact-sheet.jpg first.',
        'Use _system-review/frame-index.json for timestamps and contact sheet positions.',
        'Use evidence/review/frames for ordinary checks.',
        'Open evidence/contact-sheet.jpg or evidence/frames only for targeted detail confirmation, at most 2-3 detail frames per turn.',
        'Write analysis into recording-analysis.md.',
        'Do not analyze sibling recording directories.'
    )
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

[ordered]@{
    recording_dir = $recordingRootPath
    source_video = $sourceVideo
    review_contact_sheet = $reviewContactSheetPath
    review_frames_dir = $reviewFramesDir
    detail_contact_sheet = $contactSheetPath
    detail_frames_dir = $framesDir
    contact_sheet = $reviewContactSheetPath
    frames_dir = $reviewFramesDir
    metadata = $metadataPath
    frame_index = $frameIndexPath
    ai_input_pack = $aiInputPackPath
    source_notes = $sourceNotesPath
    recording_analysis = $analysisPath
    manifest = $manifestPath
    frame_count = $FrameCount
    detail_frame_width = $DetailFrameWidth
    review_frame_width = $ReviewFrameWidth
} | ConvertTo-Json -Depth 6
