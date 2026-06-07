Set-StrictMode -Version Latest

function Expand-TemplateText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Template,

        [hashtable]$Variables = @{}
    )

    $result = $Template
    foreach ($key in $Variables.Keys) {
        $value = if ($null -eq $Variables[$key]) { '' } else { [string]$Variables[$key] }
        $result = $result.Replace("{{$key}}", $value)
    }
    return $result
}

function Write-TemplateFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [hashtable]$Variables = @{}
    )

    $resolvedTemplate = Resolve-FilePath $TemplatePath
    $template = Get-Content -LiteralPath $resolvedTemplate -Raw -Encoding UTF8
    $content = Expand-TemplateText -Template $template -Variables $Variables
    Write-Utf8File -Path $OutputPath -Content $content
}
