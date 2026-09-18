# MK-Whois

MK-Whois provides a Linux-like `whois` experience in PowerShell. It queries WHOIS servers directly over TCP port 43 and falls back to RDAP over HTTPS when a WHOIS lookup is unavailable.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Internet access for WHOIS or RDAP lookups

## Installation

Clone or copy this repository, then import the module by path:

```powershell
Import-Module "C:\Users\MLAR\Src\Github\mklarsen\whois4ps\MK-Whois\MK-Whois.psd1"
```

To make the command available in every new PowerShell terminal, add the import to your PowerShell profile:

```powershell
$moduleManifest = "C:\Users\MLAR\Src\Github\mklarsen\whois4ps\MK-Whois\MK-Whois.psd1"
if (Test-Path $moduleManifest) {
    Import-Module $moduleManifest
}
```

Create the profile first if it does not exist:

```powershell
New-Item -ItemType File -Path $PROFILE -Force
notepad $PROFILE
```

## Usage

```powershell
# Automatic WHOIS, then RDAP fallback
Get-MKWhois example.com

# Linux-like text output
whois example.com -Text

# Force a transport
Get-MKWhois example.com -Protocol Whois
Get-MKWhois example.com -Protocol Rdap

# Return only the original response text
Get-MKWhois example.com -Raw

# Query several domains or pipeline input
'example.com', 'example.org' | Get-MKWhois
Get-Content .\domains.txt | Get-MKWhois -Text
```

The default output is a structured object with `Domain`, `Protocol`, `Status`, `Registrar`, `NameServers`, `Events`, `Fields`, and `RawText` properties. RDAP results also include `Uri` and `RawObject`.

## Tests

The tests are compatible with Pester 3.4 and later:

```powershell
Invoke-Pester .\Tests\MK-Whois.Tests.ps1
```

The parser and packaging tests do not require live network access. A live lookup can be checked after importing the module with `Get-MKWhois example.com -Text`.