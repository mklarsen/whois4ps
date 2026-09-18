[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force,
    [switch]$AddProfileImport,
    [string]$RepositoryOwner = 'mklarsen',
    [string]$RepositoryName = 'whois4ps',
    [string]$Branch = 'main',
    [string]$ArchiveUri,
    [string]$SourceArchivePath,
    [switch]$SkipSessionImport
)

$ErrorActionPreference = 'Stop'

function Read-MKInstallUpdateChoice {
    param([Parameter(Mandatory = $true)][string]$DestinationRoot)

    while ($true) {
        Write-Host "MK-Whois is already installed at '$DestinationRoot'." -ForegroundColor Yellow
        Write-Host 'Update existing installation? [Y] Yes  [A] Yes to all  [N] No  [L] No to all (default is Y): ' -NoNewline
        $answer = [Console]::ReadLine()
        if ($null -eq $answer) {
            throw 'No interactive input was available. Re-run with -Force to update without prompting.'
        }

        switch ($answer.Trim().ToLowerInvariant()) {
            '' { return 'Yes' }
            'y' { return 'Yes' }
            'yes' { return 'Yes' }
            'a' { return 'YesToAll' }
            'all' { return 'YesToAll' }
            'n' { return 'No' }
            'no' { return 'No' }
            'l' { return 'NoToAll' }
            'no to all' { return 'NoToAll' }
            default { Write-Host 'Please answer Y, A, N, or L.' -ForegroundColor Yellow }
        }
    }
}

function Install-MKWhoisModuleFolder {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][System.Version]$Version
    )

    $documentsRoot = [Environment]::GetFolderPath('MyDocuments')
    $moduleRoots = @()
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $moduleRoots += Join-Path $documentsRoot 'PowerShell\Modules'
        $moduleRoots += Join-Path $documentsRoot 'WindowsPowerShell\Modules'
    }
    else {
        $moduleRoots += Join-Path $HOME '.local/share/powershell/Modules'
    }

    $replaceAll = $false
    $skipAll = $false
    foreach ($moduleRoot in ($moduleRoots | Select-Object -Unique)) {
        $destinationRoot = Join-Path $moduleRoot 'MK-Whois'
        if ((Test-Path -LiteralPath $destinationRoot) -and -not $Force) {
            if ($skipAll) { continue }
            if (-not $replaceAll) {
                switch (Read-MKInstallUpdateChoice -DestinationRoot $destinationRoot) {
                    'Yes' { }
                    'YesToAll' { $replaceAll = $true }
                    'No' { continue }
                    'NoToAll' { $skipAll = $true; continue }
                }
            }
        }

        if ($PSCmdlet.ShouldProcess($destinationRoot, "Install MK-Whois $Version")) {
            New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
            if (Test-Path -LiteralPath $destinationRoot) {
                Remove-Item -LiteralPath $destinationRoot -Recurse -Force
            }
            Copy-Item -LiteralPath $SourceRoot -Destination $destinationRoot -Recurse
            $destinationRoot
        }
    }
}

function Add-MKWhoisProfileImport {
    if (-not $AddProfileImport) { return $false }

    $profileDirectory = Split-Path -Parent $PROFILE.CurrentUserAllHosts
    if ($PSCmdlet.ShouldProcess($PROFILE.CurrentUserAllHosts, 'Add Import-Module MK-Whois')) {
        New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
        if (-not (Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts -PathType Leaf)) {
            New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force | Out-Null
        }
        $profileLine = 'Import-Module MK-Whois -ErrorAction Stop'
        $profileContent = Get-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Raw -ErrorAction SilentlyContinue
        if ($profileContent -notmatch [regex]::Escape($profileLine)) {
            Add-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Value "`n$profileLine"
        }
    }
    return $true
}

function Import-MKWhoisInstalledModule {
    param([Parameter(Mandatory = $true)][string[]]$InstalledPath)

    if ($SkipSessionImport -or $InstalledPath.Count -eq 0) { return $false }

    $installedManifest = Join-Path $InstalledPath[0] 'MK-Whois.psd1'
    Import-Module $installedManifest -Force -Global
    Set-Alias -Name whois -Value Get-MKWhois -Scope Global -Force
    Set-Alias -Name mk-whois -Value Get-MKWhois -Scope Global -Force
    return $true
}

if (-not $ArchiveUri) {
    $ArchiveUri = "https://codeload.github.com/$RepositoryOwner/$RepositoryName/zip/refs/heads/$Branch"
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("MK-Whois-{0}" -f ([guid]::NewGuid().ToString('N')))
$downloadedArchivePath = Join-Path $temporaryRoot 'source.zip'
$extractPath = Join-Path $temporaryRoot 'source'

try {
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
    if ($SourceArchivePath) {
        if (-not (Test-Path -LiteralPath $SourceArchivePath -PathType Leaf)) {
            throw "Source archive was not found at '$SourceArchivePath'."
        }
        Copy-Item -LiteralPath $SourceArchivePath -Destination $downloadedArchivePath
    }
    else {
        Invoke-WebRequest -Uri $ArchiveUri -OutFile $downloadedArchivePath -UseBasicParsing
    }
    Expand-Archive -Path $downloadedArchivePath -DestinationPath $extractPath -Force

    $moduleRoot = Get-ChildItem -Path $extractPath -Directory -Recurse |
        Where-Object { $_.Name -eq 'MK-Whois' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'MK-Whois.psd1')) } |
        Select-Object -First 1

    if (-not $moduleRoot) {
        throw "Downloaded archive from '$ArchiveUri' did not contain the MK-Whois module."
    }

    $manifestPath = Join-Path $moduleRoot.FullName 'MK-Whois.psd1'
    $moduleInfo = Test-ModuleManifest -Path $manifestPath
    $installedPaths = Install-MKWhoisModuleFolder -SourceRoot $moduleRoot.FullName -Version $moduleInfo.Version
    $profileImport = Add-MKWhoisProfileImport
    $sessionImport = Import-MKWhoisInstalledModule -InstalledPath @($installedPaths)

    [pscustomobject]@{
        ModuleName       = 'MK-Whois'
        Version          = $moduleInfo.Version.ToString()
        Source           = $ArchiveUri
        InstalledPaths   = @($installedPaths)
        ProfileImport    = [bool]$profileImport
        SessionImport    = [bool]$sessionImport
        Commands         = @('Get-MKWhois', 'whois', 'mk-whois')
        RestartSuggested = $true
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}