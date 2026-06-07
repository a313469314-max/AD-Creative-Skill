Set-StrictMode -Version Latest

function Resolve-ProductContext {
    param(
        [string]$SkillRoot,
        [string]$ProductId,
        [string]$ProductProfileDir
    )

    if ([string]::IsNullOrWhiteSpace($ProductId) -and [string]::IsNullOrWhiteSpace($ProductProfileDir)) {
        return [pscustomobject]@{
            Enabled = $false
            ProductId = $null
            ProfileDir = $null
            Files = @()
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ProductId) -and -not [string]::IsNullOrWhiteSpace($ProductProfileDir)) {
        throw 'Use either -ProductId or -ProductProfileDir, not both.'
    }

    $profileDir = $null
    if (-not [string]::IsNullOrWhiteSpace($ProductProfileDir)) {
        $resolved = Resolve-Path -LiteralPath $ProductProfileDir -ErrorAction SilentlyContinue
        if (-not $resolved) {
            throw "ProductProfileDir not found: $ProductProfileDir"
        }
        $profileDir = $resolved.Path
    } else {
        $candidate = Join-Path $SkillRoot (Join-Path 'products' $ProductId)
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $profileDir = (Resolve-Path -LiteralPath $candidate).Path
        } else {
            $registryPath = Join-Path $SkillRoot 'products\product-registry.yaml'
            $currentId = $null
            if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
                foreach ($line in Get-Content -LiteralPath $registryPath) {
                    if ($line -match '^\s*-\s*id:\s*"?([^"#]+?)"?\s*$') {
                        $currentId = $matches[1].Trim()
                    } elseif ($currentId -eq $ProductId -and $line -match '^\s*profile_dir:\s*"?([^"#]+?)"?\s*$') {
                        $profileDirValue = $matches[1].Trim()
                        $candidate = if ([IO.Path]::IsPathRooted($profileDirValue)) {
                            $profileDirValue
                        } else {
                            Join-Path $SkillRoot $profileDirValue
                        }
                        if (Test-Path -LiteralPath $candidate -PathType Container) {
                            $profileDir = (Resolve-Path -LiteralPath $candidate).Path
                            break
                        }
                    }
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($profileDir)) {
            throw "ProductId not found in products folder or registry: $ProductId"
        }
    }

    $knownFiles = @(
        'product.yaml',
        'product-profile.md',
        'gameplay-systems.md',
        'hook-mapping.md',
        'asset-inventory.md',
        'creative-rules.md',
        'metrics-policy.md',
        'recordings\recording-index.yaml',
        'recordings\README.md',
        'materials\material-index.yaml',
        'memory\winning-patterns.md',
        'memory\rejected-patterns.md',
        'memory\test-history.md'
    )

    $files = [System.Collections.Generic.List[object]]::new()
    foreach ($relativePath in $knownFiles) {
        $path = Join-Path $profileDir $relativePath
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $files.Add([ordered]@{ name = $relativePath; path = (Resolve-Path -LiteralPath $path).Path }) | Out-Null
        }
    }

    $productYaml = Join-Path $profileDir 'product.yaml'
    if (Test-Path -LiteralPath $productYaml -PathType Leaf) {
        $inPlaybooks = $false
        foreach ($line in Get-Content -LiteralPath $productYaml) {
            if ($line -match '^primary_playbooks:\s*$') {
                $inPlaybooks = $true
                continue
            }
            if ($inPlaybooks -and $line -match '^\s*-\s*([a-z0-9-]+)\s*$') {
                $playbookPath = Join-Path $SkillRoot ("playbooks\{0}-playbook.md" -f $matches[1])
                if (Test-Path -LiteralPath $playbookPath -PathType Leaf) {
                    $files.Add([ordered]@{ name = "playbooks\$($matches[1])-playbook.md"; path = (Resolve-Path -LiteralPath $playbookPath).Path }) | Out-Null
                }
            } elseif ($inPlaybooks -and $line -match '^\S') {
                $inPlaybooks = $false
            }
        }
    }

    $productPlaybookDir = Join-Path $profileDir 'playbooks'
    if (Test-Path -LiteralPath $productPlaybookDir -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $productPlaybookDir -File -Filter '*.md') {
            $files.Add([ordered]@{ name = "playbooks\$($file.Name)"; path = $file.FullName }) | Out-Null
        }
    }

    $resolvedId = if (-not [string]::IsNullOrWhiteSpace($ProductId)) { $ProductId } else { Split-Path -Leaf $profileDir }
    return [pscustomobject]@{
        Enabled = $true
        ProductId = $resolvedId
        ProfileDir = $profileDir
        Files = @($files)
    }
}

function New-ProductContextMarkdown {
    param($ProductContext)

    if (-not $ProductContext.Enabled) {
        return @(
            'No product directory was provided.',
            'Use product-brief.md and the general methodology only. If product facts are incomplete, keep product mapping marked as pending.'
        ) -join "`r`n"
    }

    $lines = @(
        "- Product ID: $($ProductContext.ProductId)",
        "- Product directory: $($ProductContext.ProfileDir)"
    )
    foreach ($file in $ProductContext.Files) {
        $lines += "- $($file.name): $($file.path)"
    }
    $lines += ''
    $lines += 'Product directory rule: one directory serves one independent game product only.'
    $lines += 'Recording analyses belong under recordings/ and do not automatically update long-term product facts.'
    $lines += 'Product materials/memory contain current-product materials only. Competitor materials belong in the root competitors/ module, never under products/<product-id>.'
    $lines += 'Conflict priority: product-profile/gameplay-systems > hook-mapping > asset-inventory > recordings/current-product material memory > competitors > playbooks > methodology.'
    $lines += 'Playbooks provide expression guidance only; they do not define product facts.'
    $lines += 'Do not decide ad expression formats, test priority, or creative structures from product recordings alone; require current-product materials and same-playstyle competitor materials.'
    return ($lines -join "`r`n")
}
