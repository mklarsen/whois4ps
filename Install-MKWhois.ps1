[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force,
    [switch]$AddProfileImport
)

$ErrorActionPreference = 'Stop'

$moduleName = 'MK-Whois'
$sourceRoot = Join-Path $PSScriptRoot $moduleName
$sourceManifest = Join-Path $sourceRoot "$moduleName.psd1"

if (-not (Test-Path -LiteralPath $sourceManifest -PathType Leaf)) {
    throw "Module manifest was not found at '$sourceManifest'."
}

$moduleInfo = Test-ModuleManifest -Path $sourceManifest
$documentsRoot = [Environment]::GetFolderPath('MyDocuments')
$moduleRoots = @()

if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    $moduleRoots += Join-Path $documentsRoot 'PowerShell\Modules'
    $moduleRoots += Join-Path $documentsRoot 'WindowsPowerShell\Modules'
}
else {
    $moduleRoots += Join-Path $HOME '.local/share/powershell/Modules'
}

$installedPaths = foreach ($moduleRoot in ($moduleRoots | Select-Object -Unique)) {
    $destinationRoot = Join-Path $moduleRoot $moduleName
    if ((Test-Path -LiteralPath $destinationRoot) -and -not $Force) {
        throw "'$destinationRoot' already exists. Re-run with -Force to replace it."
    }

    if ($PSCmdlet.ShouldProcess($destinationRoot, "Install $moduleName $($moduleInfo.Version)")) {
        New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
        if (Test-Path -LiteralPath $destinationRoot) {
            Remove-Item -LiteralPath $destinationRoot -Recurse -Force
        }
        Copy-Item -LiteralPath $sourceRoot -Destination $destinationRoot -Recurse
        $destinationRoot
    }
}

if ($AddProfileImport) {
    $profileDirectory = Split-Path -Parent $PROFILE.CurrentUserAllHosts
    if ($PSCmdlet.ShouldProcess($PROFILE.CurrentUserAllHosts, "Add Import-Module $moduleName")) {
        New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
        if (-not (Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts -PathType Leaf)) {
            New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force | Out-Null
        }
        $profileLine = "Import-Module $moduleName -ErrorAction Stop"
        $profileContent = Get-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Raw -ErrorAction SilentlyContinue
        if ($profileContent -notmatch [regex]::Escape($profileLine)) {
            Add-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Value "`n$profileLine"
        }
    }
}

[pscustomobject]@{
    ModuleName       = $moduleName
    Version          = $moduleInfo.Version.ToString()
    InstalledPaths   = @($installedPaths)
    ProfileImport    = [bool]$AddProfileImport
    Commands         = @('Get-MKWhois', 'whois', 'mk-whois')
    RestartSuggested = $true
}