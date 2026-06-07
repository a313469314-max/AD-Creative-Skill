Set-StrictMode -Version Latest

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowNull()]
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function Resolve-FilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "Path not found: $Path"
    }
    return $resolved.Path
}

function Resolve-Executable {
    param(
        [string]$ExplicitPath,

        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return Resolve-FilePath $ExplicitPath
    }

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $paramName = if ($CommandName -eq 'ffmpeg') { 'FfmpegPath' } elseif ($CommandName -eq 'ffprobe') { 'FfprobePath' } else { "$($CommandName)Path" }
        throw "Required executable not found on PATH: $CommandName. Install it first or pass -$paramName with the full executable path."
    }
    return $cmd.Source
}

function Invoke-Logged {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Exe,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
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
    Write-Utf8File -Path $LogPath -Content ($combined -join "`r`n")

    if ($exitCode -ne 0) {
        if ($AllowFailure) {
            return $false
        }
        throw "Command failed. See log: $LogPath"
    }
    return $true
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

function New-SafeSlug {
    param([string]$Value)

    $lower = $Value.ToLowerInvariant()
    $chars = New-Object System.Collections.Generic.List[char]
    $lastWasDash = $false
    foreach ($ch in $lower.ToCharArray()) {
        $isAsciiLetter = ($ch -ge 'a' -and $ch -le 'z')
        $isDigit = ($ch -ge '0' -and $ch -le '9')
        if ($isAsciiLetter -or $isDigit) {
            $chars.Add($ch) | Out-Null
            $lastWasDash = $false
        } elseif (-not $lastWasDash) {
            $chars.Add('-') | Out-Null
            $lastWasDash = $true
        }
    }
    $slug = (-join $chars).Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return 'source-video'
    }
    if ($slug.Length -lt 3 -or $slug -match '^[0-9]') {
        return "source-$slug"
    }
    return $slug
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $baseFull = [IO.Path]::GetFullPath($BasePath)
    if (-not $baseFull.EndsWith([IO.Path]::DirectorySeparatorChar)) {
        $baseFull += [IO.Path]::DirectorySeparatorChar
    }
    $targetFull = [IO.Path]::GetFullPath($FullPath)
    $baseUri = [Uri]::new($baseFull)
    $targetUri = [Uri]::new($targetFull)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', [IO.Path]::DirectorySeparatorChar)
}

function Format-TimestampLabel {
    param([double]$Seconds)

    $ts = [TimeSpan]::FromSeconds($Seconds)
    if ($ts.Hours -gt 0) {
        return ('{0:D2}h{1:D2}m{2:D2}s' -f $ts.Hours, $ts.Minutes, $ts.Seconds)
    }
    return ('{0:D2}m{1:D2}s' -f $ts.Minutes, $ts.Seconds)
}

function New-ScaleFilter {
    param([int]$Width)

    return "scale='min($Width,iw)':-1"
}

function New-TileSheet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Ffmpeg,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [int]$Count,

        [Parameter(Mandatory = $true)]
        [int]$Columns,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [string[]]$ExtraArguments = @()
    )

    if ($Count -le 0) {
        return $false
    }
    $rows = [Math]::Ceiling($Count / $Columns)
    $args = @(
        '-hide_banner', '-y',
        '-framerate', '1',
        '-i', $Pattern,
        '-vf', "tile=${Columns}x${rows}:padding=4:margin=2",
        '-frames:v', '1'
    ) + $ExtraArguments + @($OutputPath)

    Invoke-Logged -Exe $Ffmpeg -Arguments $args -LogPath $LogPath | Out-Null
    return $true
}
