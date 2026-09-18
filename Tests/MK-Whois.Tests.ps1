$testRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Join-Path $testRoot '..\MK-Whois'
$manifestPath = Join-Path $moduleRoot 'MK-Whois.psd1'
$modulePath = Join-Path $moduleRoot 'MK-Whois.psm1'

Describe 'MK-Whois module packaging' {
    It 'has a valid module manifest' {
        $manifest = Test-ModuleManifest -Path $manifestPath
        $manifest.Name | Should Be 'MK-Whois'
        $manifest | Should Not BeNullOrEmpty
        $manifestData = Import-PowerShellDataFile -Path $manifestPath
        ($manifestData.FunctionsToExport -contains 'Get-MKWhois') | Should Be $true
        ($manifestData.AliasesToExport -contains 'whois') | Should Be $true
        ($manifestData.AliasesToExport -contains 'mk-whois') | Should Be $true
    }

    It 'imports the public command and alias' {
        Import-Module $manifestPath -Force
        (Get-Command Get-MKWhois).CommandType | Should Be 'Function'
        (Get-Command whois).Definition | Should Be 'Get-MKWhois'
        (Get-Command mk-whois).Definition | Should Be 'Get-MKWhois'
        Remove-Module MK-Whois -ErrorAction SilentlyContinue
    }
}

Describe 'MK-Whois implementation contract' {
    It 'contains separate WHOIS and RDAP transport implementations' {
        $source = Get-Content -Path $modulePath -Raw
        $source | Should Match 'function Invoke-MKWhoisTcp'
        $source | Should Match 'function Invoke-MKRdap'
        $source | Should Match 'Get-MKRdapBaseUri'
    }

    It 'defines explicit domain validation' {
        $source = Get-Content -Path $modulePath -Raw
        $source | Should Match "is not a valid domain name"
        $source | Should Match '\[string\]\$Name'
    }

    It 'exposes protocol, raw, text, and timeout parameters' {
        Import-Module $manifestPath -Force
        $parameters = (Get-Command Get-MKWhois).Parameters
        ($parameters.Keys -contains 'Protocol') | Should Be $true
        ($parameters.Keys -contains 'Raw') | Should Be $true
        ($parameters.Keys -contains 'Text') | Should Be $true
        ($parameters.Keys -contains 'TimeoutMilliseconds') | Should Be $true
    }
}

Describe 'MK-Whois installer' {
    It 'provides a current-user installer for PSModulePath installation' {
        $installerPath = Join-Path $testRoot '..\Install-MKWhois.ps1'
        $source = Get-Content -Path $installerPath -Raw
        $source | Should Match 'PowerShell\\Modules'
        $source | Should Match 'WindowsPowerShell\\Modules'
        $source | Should Match 'AddProfileImport'
        $source | Should Match 'Read-MKInstallUpdateChoice'
        $source | Should Match 'Update existing installation\?'
        $source | Should Match 'Re-run with -Force to update without prompting'
    }

    It 'provides a standalone online installer' {
        $installerPath = Join-Path $testRoot '..\Install-MKWhoisOnline.ps1'
        $source = Get-Content -Path $installerPath -Raw
        $source | Should Match 'codeload.github.com'
        $source | Should Match 'Invoke-WebRequest'
        $source | Should Match 'Expand-Archive'
        $source | Should Match 'Install-MKWhoisModuleFolder'
        $source | Should Match 'SourceArchivePath'
    }
}