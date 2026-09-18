Set-StrictMode -Version 2.0

function Get-MKDomainName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = $Name.Trim().ToLowerInvariant()
    if ($value -match '^https?://') {
        $value = ([System.Uri]$value).Host
    }
    $value = $value.TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$') {
        throw "'$Name' is not a valid domain name."
    }
    return $value
}

function Get-MKWhoisServer {
    param([Parameter(Mandatory = $true)][string]$Domain)

    $servers = @{
        'com' = 'whois.verisign-grs.com'; 'net' = 'whois.verisign-grs.com'; 'org' = 'whois.pir.org'
        'io' = 'whois.nic.io'; 'dev' = 'whois.nic.google'; 'app' = 'whois.nic.google'
        'co' = 'whois.nic.co'; 'uk' = 'whois.nic.uk'; 'dk' = 'whois.dk-hostmaster.dk'
        'de' = 'whois.denic.de'; 'fr' = 'whois.afnic.fr'; 'nl' = 'whois.domain-registry.nl'
        'se' = 'whois.iis.se'; 'no' = 'whois.norid.no'; 'eu' = 'whois.eu'; 'info' = 'whois.afilias.net'
    }
    $tld = ($Domain -split '\.')[-1]
    if ($servers.ContainsKey($tld)) { return $servers[$tld] }
    return 'whois.iana.org'
}

function Invoke-MKWhoisTcp {
    param(
        [Parameter(Mandatory = $true)][string]$Domain,
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][int]$TimeoutMilliseconds
    )

    $client = New-Object System.Net.Sockets.TcpClient
    $reader = $null
    $writer = $null
    try {
        $connect = $client.BeginConnect($Server, 43, $null, $null)
        if (-not $connect.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) {
            throw "WHOIS connection to '$Server' timed out."
        }
        $client.EndConnect($connect)
        $client.ReceiveTimeout = $TimeoutMilliseconds
        $client.SendTimeout = $TimeoutMilliseconds
        $stream = $client.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.ASCIIEncoding))
        $writer.NewLine = "`r`n"
        $writer.WriteLine($Domain)
        $writer.Flush()
        $reader = New-Object System.IO.StreamReader($stream, (New-Object System.Text.Encoding.ASCII))
        return $reader.ReadToEnd()
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($writer) { $writer.Dispose() }
        if ($client) { $client.Close() }
    }
}

function Get-MKWhoisReferral {
    param([Parameter(Mandatory = $true)][string]$Response)
    $match = [regex]::Match($Response, '(?im)^\s*(?:whois|refer)\s*:\s*(\S+)')
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $null
}

function ConvertFrom-MKWhoisText {
    param(
        [Parameter(Mandatory = $true)][string]$Domain,
        [Parameter(Mandatory = $true)][string]$Response,
        [Parameter(Mandatory = $true)][string]$Server
    )

    $fields = [ordered]@{}
    foreach ($line in ($Response -split "`r?`n")) {
        if ($line -match '^\s*([^:#][^:]{1,80})\s*:\s*(.*)$') {
            $key = ($matches[1].Trim() -replace '[^a-zA-Z0-9]+', '_').Trim('_')
            if ($key) {
                if ($fields.Contains($key)) { $fields[$key] = @($fields[$key]) + $matches[2].Trim() }
                else { $fields[$key] = $matches[2].Trim() }
            }
        }
    }
    $nameServers = @($fields['Name_Server'], $fields['Name_Servers'] | Where-Object { $_ })
    return [pscustomobject]@{
        Domain      = $Domain
        Protocol    = 'Whois'
        Server      = $Server
        Status      = if ($fields['Domain_Status']) { @($fields['Domain_Status']) } else { @() }
        Registrar   = $fields['Registrar']
        NameServers = @($nameServers | ForEach-Object { $_ } | Select-Object -Unique)
        Events      = @()
        Fields      = [pscustomobject]$fields
        RawText     = $Response
        RetrievedAt = [datetime]::UtcNow
    }
}

function Get-MKRdapBaseUri {
    param([Parameter(Mandatory = $true)][string]$Domain, [int]$TimeoutSeconds = 10)
    $tld = ($Domain -split '\.')[-1]
    $bootstrap = Invoke-RestMethod -Uri 'https://data.iana.org/rdap/dns.json' -Method Get -TimeoutSec $TimeoutSeconds
    foreach ($service in $bootstrap.services) {
        if (@($service[0]) -contains $tld) { return [string]$service[1][0] }
    }
    return $null
}

function Invoke-MKRdap {
    param([Parameter(Mandatory = $true)][string]$Domain, [Parameter(Mandatory = $true)][int]$TimeoutMilliseconds)
    $baseUri = Get-MKRdapBaseUri -Domain $Domain -TimeoutSeconds ([math]::Max(1, [int]($TimeoutMilliseconds / 1000)))
    if (-not $baseUri) { throw "No RDAP service was found for '$Domain'." }
    $uri = $baseUri.TrimEnd('/') + '/domain/' + [uri]::EscapeDataString($Domain)
    $data = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec ([math]::Max(1, [int]($TimeoutMilliseconds / 1000))) -Headers @{ Accept = 'application/rdap+json, application/json' }
    $names = @($data.nameservers | ForEach-Object { $_.ldhName } | Where-Object { $_ })
    $statuses = @($data.status)
    $events = @($data.events | ForEach-Object { [pscustomobject]@{ Event = $_.eventAction; Date = $_.eventDate } })
    $registrar = @($data.entities | Where-Object { $_.roles -contains 'registrar' } | ForEach-Object { $_.vcardArray[1] | Where-Object { $_[0] -eq 'fn' } | ForEach-Object { $_[3] } })[0]
    return [pscustomobject]@{
        Domain      = $Domain
        Protocol    = 'RDAP'
        Server      = $null
        Uri         = $uri
        Status      = $statuses
        Registrar   = $registrar
        NameServers = $names
        Events      = $events
        Fields      = $data
        RawText     = ($data | ConvertTo-Json -Depth 20)
        RawObject   = $data
        RetrievedAt = [datetime]::UtcNow
    }
}

function Format-MKWhoisText {
    param([Parameter(Mandatory = $true)][psobject]$Result)
    if ($Result.Protocol -eq 'Whois') { return $Result.RawText.TrimEnd() }
    $lines = @("Domain Name: $($Result.Domain)", "Protocol: $($Result.Protocol)")
    if ($Result.Registrar) { $lines += "Registrar: $($Result.Registrar)" }
    if ($Result.Status.Count -gt 0) { $lines += "Status: $($Result.Status -join ', ')" }
    if ($Result.NameServers.Count -gt 0) { $lines += "Name Servers: $($Result.NameServers -join ', ')" }
    foreach ($event in $Result.Events) { $lines += "$($event.Event): $($event.Date)" }
    return ($lines -join [Environment]::NewLine)
}

function Get-MKWhois {
    [CmdletBinding(DefaultParameterSetName = 'Domain')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Domain', 'Query')]
        [string[]]$Name,
        [ValidateSet('Auto', 'Whois', 'Rdap')]
        [string]$Protocol = 'Auto',
        [switch]$Raw,
        [switch]$Text,
        [ValidateRange(500, 120000)]
        [int]$TimeoutMilliseconds = 5000
    )
    process {
        foreach ($item in $Name) {
            $domain = Get-MKDomainName -Name $item
            $result = $null
            $whoisError = $null
            if ($Protocol -in @('Auto', 'Whois')) {
                try {
                    $server = Get-MKWhoisServer -Domain $domain
                    $response = Invoke-MKWhoisTcp -Domain $domain -Server $server -TimeoutMilliseconds $TimeoutMilliseconds
                    $referral = Get-MKWhoisReferral -Response $response
                    if ($referral -and $referral -ne $server -and $server -eq 'whois.iana.org') {
                        $server = $referral
                        $response = Invoke-MKWhoisTcp -Domain $domain -Server $server -TimeoutMilliseconds $TimeoutMilliseconds
                    }
                    $result = ConvertFrom-MKWhoisText -Domain $domain -Response $response -Server $server
                }
                catch { $whoisError = $_.Exception.Message }
            }
            if (-not $result -and $Protocol -in @('Auto', 'Rdap')) {
                try { $result = Invoke-MKRdap -Domain $domain -TimeoutMilliseconds $TimeoutMilliseconds }
                catch {
                    if ($Protocol -eq 'Rdap') { throw }
                    throw "WHOIS and RDAP lookup failed for '$domain'. WHOIS: $whoisError RDAP: $($_.Exception.Message)"
                }
            }
            if ($Raw) { $result.RawText; continue }
            if ($Text) { Format-MKWhoisText -Result $result; continue }
            $result
        }
    }
}

Set-Alias -Name whois -Value Get-MKWhois
Set-Alias -Name mk-whois -Value Get-MKWhois
Export-ModuleMember -Function Get-MKWhois -Alias whois, mk-whois