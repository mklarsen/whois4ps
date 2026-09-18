# MK-Whois

MK-Whois provides a Linux-like `whois` experience in PowerShell. It queries WHOIS servers directly over TCP port 43 and falls back to RDAP over HTTPS when a WHOIS lookup is unavailable.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Internet access for WHOIS or RDAP lookups

## Installation

Install directly from GitHub with PowerShell:

```powershell
& ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/mklarsen/whois4ps/main/Install-MKWhoisOnline.ps1'))) -Force -AddProfileImport
```

Or with `curl` and PowerShell:

```powershell
curl.exe -fsSL https://raw.githubusercontent.com/mklarsen/whois4ps/main/Install-MKWhoisOnline.ps1 | pwsh -NoProfile -Command - -Force -AddProfileImport
```

The installer imports MK-Whois into the current session so `whois` works immediately, even if another WHOIS module is already installed. `-AddProfileImport` makes the `whois` and `mk-whois` aliases win consistently in new PowerShell terminals too. Review remote install scripts before running them in environments you do not control.

## Local Installation

Clone this repository, then run the installer from the repository root:

```powershell
.\Install-MKWhois.ps1
```

The installer copies the module into the current user's PowerShell module paths. If MK-Whois is already installed, the installer asks whether it should update the existing installation. Press Enter or `Y` to update, `A` to update all module paths, `N` to skip one path, or `L` to skip all remaining paths. After opening a new PowerShell terminal, PowerShell can auto-load the module when you run `Get-MKWhois`, `whois`, or `mk-whois`.

To replace an existing installation without prompting, use `-Force`:

```powershell
.\Install-MKWhois.ps1 -Force
```

For the most predictable alias experience in every new terminal, let the installer add a profile import:

```powershell
.\Install-MKWhois.ps1 -Force -AddProfileImport
```

This adds the following line to the current user's all-hosts profile when it is not already present:

```powershell
Import-Module MK-Whois -ErrorAction Stop
```

You can still import the module directly from the repository without installing it:

```powershell
Import-Module "C:\Users\MLAR\Src\Github\mklarsen\whois4ps\MK-Whois\MK-Whois.psd1"
```

## Usage

```powershell
# Automatic WHOIS, then RDAP fallback
Get-MKWhois example.com

# Linux-like text output
whois example.com -Text
mk-whois example.com -Text

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

## Support

If MK-Whois saves you time or makes PowerShell a little nicer to use, you can support the project here:

[Buy Martin a coffee](https://buymeacoffee.com/mklarsen)