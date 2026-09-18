@{
    RootModule        = 'MK-Whois.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '0e3a6a39-3c4b-4a18-a9cb-0b6b8e3f5f1a'
    Author            = 'Martin Kraus Larsen'
    CompanyName       = ''
    Copyright         = '(c) Martin Kraus Larsen. All rights reserved.'
    Description       = 'A Linux-like WHOIS client for PowerShell with TCP port 43 and RDAP fallback.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-MKWhois')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('whois', 'mk-whois')
    PrivateData       = @{
        PSData = @{
            Tags = @('WHOIS', 'RDAP', 'DNS', 'Network', 'PowerShell')
        }
    }
}