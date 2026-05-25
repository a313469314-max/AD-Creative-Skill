param(
    [string]$FfmpegPath,
    [string]$FfprobePath,
    [switch]$KeepOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
$tmpRoot = Join-Path $repoRoot.Path '.tmp\regression-tests'
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null

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

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Remove-TestRoot {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $resolved = Resolve-Path -LiteralPath $Path
    $tmpResolved = Resolve-Path -LiteralPath $tmpRoot
    if (-not $resolved.Path.StartsWith($tmpResolved.Path)) {
        throw "Refusing to remove path outside regression test root: $($resolved.Path)"
    }
    Remove-Item -LiteralPath $resolved.Path -Recurse -Force
}

function New-TestDir {
    param([string]$Name)
    $path = Join-Path $tmpRoot $Name
    if (Test-Path -LiteralPath $path) {
        Remove-TestRoot -Path $path
    }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Invoke-NativeCommand {
    param(
        [string]$Exe,
        [string[]]$Arguments,
        [string]$LogPath
    )
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Exe @Arguments *> $LogPath
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "Command failed with exit code $exitCode. See log: $LogPath"
    }
}

function Invoke-PowerShellFile {
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters
    )
    $powershellExe = Resolve-Executable -CommandName 'powershell'
    $wrapperPath = Join-Path $tmpRoot ("invoke-wrapper-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))

    function Convert-ToPowerShellLiteral {
        param($Value)
        if ($null -eq $Value) {
            return '$null'
        }
        if ($Value -is [bool]) {
            if ($Value) { return '$true' }
            return '$false'
        }
        if ($Value -is [System.Management.Automation.SwitchParameter]) {
            if ($Value.IsPresent) { return '$true' }
            return '$false'
        }
        if ($Value -is [System.Array]) {
            return '@(' + (($Value | ForEach-Object { Convert-ToPowerShellLiteral $_ }) -join ', ') + ')'
        }
        $stringValue = [string]$Value
        return "'" + $stringValue.Replace("'", "''") + "'"
    }

    $wrapperLines = @(
        '$ErrorActionPreference = ''Stop'''
        '$params = @{}'
    )
    foreach ($key in $Parameters.Keys) {
        $wrapperLines += ('$params[{0}] = {1}' -f (Convert-ToPowerShellLiteral $key), (Convert-ToPowerShellLiteral $Parameters[$key]))
    }
    $wrapperLines += ('& {0} @params' -f (Convert-ToPowerShellLiteral $ScriptPath))
    $wrapperLines | Set-Content -LiteralPath $wrapperPath -Encoding UTF8

    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $wrapperPath)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $powershellExe @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if (Test-Path -LiteralPath $wrapperPath) {
            Remove-Item -LiteralPath $wrapperPath -Force
        }
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function New-SyntheticVideo {
    param(
        [string]$Ffmpeg,
        [string]$OutputPath,
        [string]$LavfiInput,
        [string]$DurationSeconds,
        [string]$LogPath
    )
    Invoke-NativeCommand -Exe $Ffmpeg -Arguments @(
        '-hide_banner',
        '-y',
        '-f',
        'lavfi',
        '-i',
        $LavfiInput,
        '-t',
        $DurationSeconds,
        '-pix_fmt',
        'yuv420p',
        $OutputPath
    ) -LogPath $LogPath
}

function New-SyntheticAudio {
    param(
        [string]$Ffmpeg,
        [string]$OutputPath,
        [string]$LogPath
    )
    Invoke-NativeCommand -Exe $Ffmpeg -Arguments @(
        '-hide_banner',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=880:duration=2',
        $OutputPath
    ) -LogPath $LogPath
}

function Test-AstParsing {
    $files = Get-ChildItem -LiteralPath (Join-Path $repoRoot.Path 'scripts') -File -Filter '*.ps1'
    $parseErrors = @()
    foreach ($file in $files) {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        if ($errors.Count -gt 0) {
            $parseErrors += [pscustomobject]@{
                File = $file.FullName
                Errors = ($errors | ForEach-Object { $_.Message }) -join ' | '
            }
        }
    }
    Assert-Condition -Condition ($parseErrors.Count -eq 0) -Message ("AST parse failed: " + (($parseErrors | ForEach-Object { "$($_.File): $($_.Errors)" }) -join '; '))
}

function Test-SinglePathWithSpaces {
    param(
        [string]$Ffmpeg,
        [string]$Ffprobe
    )
    $testRoot = New-TestDir -Name 'single-path-with-spaces'
    $videoDir = Join-Path $testRoot 'videos with spaces'
    $baseDir = Join-Path $testRoot 'creative materials with spaces'
    New-Item -ItemType Directory -Path $videoDir, $baseDir -Force | Out-Null

    $videoPath = Join-Path $videoDir 'reference video spaced name.mp4'
    New-SyntheticVideo -Ffmpeg $Ffmpeg -OutputPath $videoPath -LavfiInput 'testsrc=size=720x1280:rate=30' -DurationSeconds '2.5' -LogPath (Join-Path $testRoot 'ffmpeg-single-generate.log')

    $scriptPath = Join-Path $PSScriptRoot 'process-reference-video-phase1.ps1'
    $result = Invoke-PowerShellFile -ScriptPath $scriptPath -Parameters @{
        VideoPath = $videoPath
        Slug = 'space-test'
        Name = 'space-test'
        BaseDir = $baseDir
        FfmpegPath = $Ffmpeg
        FfprobePath = $Ffprobe
        Copy = $true
        StoryboardFrames = 6
    }

    Assert-Condition -Condition ($result.ExitCode -eq 0) -Message "single path-with-spaces test failed: $($result.Output)"
    $json = $result.Output | ConvertFrom-Json
    foreach ($field in @('material_folder', 'check_status', 'check_errors', 'check_warnings')) {
        Assert-Condition -Condition ($null -ne $json.$field) -Message "single result missing field: $field"
    }
    Assert-Condition -Condition ($json.check_status -eq 'passed') -Message "single check_status expected passed, got: $($json.check_status)"

    $materialDir = $json.material_folder
    $contactSheets = @(Get-ChildItem -LiteralPath $materialDir -File -Filter 'keyframes-reference-storyboard-contact-sheet-*.jpg' -ErrorAction SilentlyContinue)
    Assert-Condition -Condition ($contactSheets.Count -ge 1) -Message "single material missing keyframe contact sheet: $materialDir"
    foreach ($path in @(
        (Join-Path $materialDir 'brief.md'),
        (Join-Path $materialDir 'product-brief.md'),
        (Join-Path $materialDir 'outputs'),
        (Join-Path $materialDir '_system-review')
    )) {
        Assert-Condition -Condition (Test-Path -LiteralPath $path) -Message "single material missing expected path: $path"
    }
}

function Test-MixAutoCheck {
    param(
        [string]$Ffmpeg,
        [string]$Ffprobe
    )
    $testRoot = New-TestDir -Name 'mix-auto-check'
    $videoDir = Join-Path $testRoot 'inputs'
    $baseDir = Join-Path $testRoot 'creative-materials'
    New-Item -ItemType Directory -Path $videoDir, $baseDir -Force | Out-Null

    $video1 = Join-Path $videoDir 'mix clip 01.mp4'
    $video2 = Join-Path $videoDir 'mix clip 02.mp4'
    New-SyntheticVideo -Ffmpeg $Ffmpeg -OutputPath $video1 -LavfiInput 'testsrc=size=720x1280:rate=30' -DurationSeconds '2.2' -LogPath (Join-Path $testRoot 'ffmpeg-mix-1.log')
    New-SyntheticVideo -Ffmpeg $Ffmpeg -OutputPath $video2 -LavfiInput 'testsrc2=size=720x1280:rate=24' -DurationSeconds '3.1' -LogPath (Join-Path $testRoot 'ffmpeg-mix-2.log')

    $scriptPath = Join-Path $PSScriptRoot 'process-reference-videos-mix.ps1'
    $result = Invoke-PowerShellFile -ScriptPath $scriptPath -Parameters @{
        VideoPaths = @($video1, $video2)
        Slug = 'mix-test'
        Name = 'mix-test'
        BaseDir = $baseDir
        FfmpegPath = $Ffmpeg
        FfprobePath = $Ffprobe
        Copy = $true
        StoryboardFrames = 6
    }

    Assert-Condition -Condition ($result.ExitCode -eq 0) -Message "mix auto-check test failed: $($result.Output)"
    $json = $result.Output | ConvertFrom-Json
    foreach ($field in @('check_status', 'check_errors', 'check_warnings')) {
        Assert-Condition -Condition ($null -ne $json.$field) -Message "mix result missing field: $field"
    }
    Assert-Condition -Condition ($json.check_status -eq 'passed') -Message "mix check_status expected passed, got: $($json.check_status)"

    $materialDir = $json.material_folder
    foreach ($path in @(
        (Join-Path $materialDir 'outputs\shared-analysis-mix.md'),
        (Join-Path $materialDir '_system-review\run-manifest.json'),
        (Join-Path $materialDir '_system-review\frame-index.json'),
        (Join-Path $materialDir '_system-review\video_metadata.json'),
        (Join-Path $materialDir '_system-review\ai-input-pack.md')
    )) {
        Assert-Condition -Condition (Test-Path -LiteralPath $path) -Message "mix material missing expected path: $path"
    }
}

function Test-MixRejectsAudioOnlyInput {
    param(
        [string]$Ffmpeg,
        [string]$Ffprobe
    )
    $testRoot = New-TestDir -Name 'mix-audio-rejection'
    $videoDir = Join-Path $testRoot 'inputs'
    $baseDir = Join-Path $testRoot 'creative-materials'
    New-Item -ItemType Directory -Path $videoDir, $baseDir -Force | Out-Null

    $videoPath = Join-Path $videoDir 'valid video.mp4'
    $audioPath = Join-Path $videoDir 'audio only sample.wav'
    New-SyntheticVideo -Ffmpeg $Ffmpeg -OutputPath $videoPath -LavfiInput 'testsrc=size=720x1280:rate=30' -DurationSeconds '2.4' -LogPath (Join-Path $testRoot 'ffmpeg-valid-video.log')
    New-SyntheticAudio -Ffmpeg $Ffmpeg -OutputPath $audioPath -LogPath (Join-Path $testRoot 'ffmpeg-audio.log')

    $scriptPath = Join-Path $PSScriptRoot 'process-reference-videos-mix.ps1'
    $result = Invoke-PowerShellFile -ScriptPath $scriptPath -Parameters @{
        VideoPaths = @($videoPath, $audioPath)
        Slug = 'mix-audio'
        Name = 'mix-audio'
        BaseDir = $baseDir
        FfmpegPath = $Ffmpeg
        FfprobePath = $Ffprobe
        Copy = $true
        StoryboardFrames = 6
    }

    Assert-Condition -Condition ($result.ExitCode -ne 0) -Message 'mix audio-only rejection test expected failure exit code.'
    Assert-Condition -Condition ($result.Output -match 'No video stream found') -Message "mix audio-only rejection test missing clear error message: $($result.Output)"
    foreach ($unexpected in @('NullReference', 'Index was outside the bounds', 'ConvertFrom-Json')) {
        Assert-Condition -Condition (-not ($result.Output -match [Regex]::Escape($unexpected))) -Message "mix audio-only rejection test contained hidden/internal error text: $unexpected"
    }
}

$ffmpeg = Resolve-Executable -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
$ffprobe = Resolve-Executable -ExplicitPath $FfprobePath -CommandName 'ffprobe'

$tests = @(
    [pscustomobject]@{ Name = 'AST parsing'; Action = { Test-AstParsing } },
    [pscustomobject]@{ Name = 'single path with spaces'; Action = { Test-SinglePathWithSpaces -Ffmpeg $ffmpeg -Ffprobe $ffprobe } },
    [pscustomobject]@{ Name = 'mix auto check'; Action = { Test-MixAutoCheck -Ffmpeg $ffmpeg -Ffprobe $ffprobe } },
    [pscustomobject]@{ Name = 'mix audio-only rejection'; Action = { Test-MixRejectsAudioOnlyInput -Ffmpeg $ffmpeg -Ffprobe $ffprobe } }
)

$passed = 0
foreach ($test in $tests) {
    & $test.Action
    $passed++
    "PASS: $($test.Name)"
}

"Regression tests passed: $passed/$($tests.Count)"

if (-not $KeepOutput) {
    Remove-TestRoot -Path $tmpRoot
    "Removed regression test output. Use -KeepOutput to inspect generated files."
}
