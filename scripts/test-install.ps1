param(
    [string]$FfmpegPath,
    [string]$FfprobePath,
    [switch]$KeepOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
$tmpRoot = Join-Path $repoRoot.Path '.tmp\test-install'
$outputDir = Join-Path $tmpRoot 'creative-materials'
New-Item -ItemType Directory -Path $tmpRoot, $outputDir -Force | Out-Null

function Resolve-Executable {
    param([string]$ExplicitPath, [string]$CommandName)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "$CommandName not found. Run scripts/install-ffmpeg.ps1 or pass explicit paths."
    }
    return $cmd.Source
}

$ffmpeg = Resolve-Executable -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
$ffprobe = Resolve-Executable -ExplicitPath $FfprobePath -CommandName 'ffprobe'

$sample = Get-ChildItem -LiteralPath $repoRoot.Path -File -Filter 'shower.*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sample) {
    $videoPath = $sample.FullName
    "Using local sample video: $videoPath"
} else {
    $videoPath = Join-Path $tmpRoot 'generated-test-video.mp4'
    $generateLog = Join-Path $tmpRoot 'ffmpeg-generate.log'
    $stdoutPath = "$generateLog.stdout"
    $stderrPath = "$generateLog.stderr"
    $process = Start-Process -FilePath $ffmpeg `
        -ArgumentList @('-hide_banner', '-y', '-f', 'lavfi', '-i', 'testsrc=size=720x1280:rate=30', '-t', '3', '-pix_fmt', 'yuv420p', $videoPath) `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -Wait `
        -NoNewWindow `
        -PassThru
    $combined = @()
    if (Test-Path -LiteralPath $stdoutPath) {
        $combined += Get-Content -LiteralPath $stdoutPath
        Remove-Item -LiteralPath $stdoutPath -Force
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $combined += Get-Content -LiteralPath $stderrPath
        Remove-Item -LiteralPath $stderrPath -Force
    }
    $combined | Set-Content -LiteralPath $generateLog -Encoding UTF8
    if ($process.ExitCode -ne 0) {
        throw "Failed to generate test video. See: $(Join-Path $tmpRoot 'ffmpeg-generate.log')"
    }
    "Generated synthetic test video: $videoPath"
}

$resultJson = & (Join-Path $PSScriptRoot 'process-reference-video-phase1.ps1') `
    -VideoPath $videoPath `
    -Slug 'test-install' `
    -Name 'test-install' `
    -BaseDir $outputDir `
    -FfmpegPath $ffmpeg `
    -FfprobePath $ffprobe `
    -Copy `
    -StoryboardFrames 6 | Out-String

if ($LASTEXITCODE -ne 0) {
    throw 'process-reference-video-phase1.ps1 failed.'
}
$result = $resultJson | ConvertFrom-Json

& (Join-Path $PSScriptRoot 'check-creative-material.ps1') -MaterialDir $result.material_folder
if ($LASTEXITCODE -ne 0) {
    throw 'check-creative-material.ps1 failed.'
}

"Test install passed. Material folder: $($result.material_folder)"

if (-not $KeepOutput) {
    $tmpResolved = Resolve-Path -LiteralPath $tmpRoot
    $repoTmp = Resolve-Path -LiteralPath (Join-Path $repoRoot.Path '.tmp')
    if (-not $tmpResolved.Path.StartsWith($repoTmp.Path)) {
        throw "Refusing to remove test directory outside repo .tmp: $($tmpResolved.Path)"
    }
    Remove-Item -LiteralPath $tmpResolved.Path -Recurse -Force
    "Removed test output. Use -KeepOutput to inspect generated files."
}
