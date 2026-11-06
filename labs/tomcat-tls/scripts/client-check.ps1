<#
.SYNOPSIS
    client-check.ps1 - Windows Server 2022 Guest Client TLS Verification Script
.DESCRIPTION
    Automates TLS trust inspection and testing for the university Tomcat 7 TLS lab.
    Runs exclusively inside the designated VirtualBox guest VM (Windows Server 2022).
    Verifies root certificate presence in CurrentUser and LocalMachine stores, performs
    live TLS HTTP handshakes to IP and DNS endpoints without bypassing validation,
    and exports structured JSON results.

    Actions:
      - Before : Inspect initial trust stores and baseline TLS endpoints (expected untrusted).
      - Import : Validate pinned rootCA.pem thumbprint and import into CurrentUser Root store.
      - After  : Inspect post-import trust stores and test TLS endpoints (expected trusted).
      - Remove : Remove only the matching lab Root CA from CurrentUser Root store and record.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Expected SHA-1 or SHA-256 thumbprint of the Course Lab Root CA")]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedThumbprint,

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateSet("Before", "Import", "After", "Remove")]
    [string]$Action = "Before",

    [Parameter(Mandatory = $false)]
    [string]$RootCertPath = "C:\InfosecTomcat\rootCA.pem",

    [Parameter(Mandatory = $false)]
    [string]$ResultsDir = "C:\InfosecTomcat\results"
)

# -----------------------------------------------------------------------------
# 1. Environment & Host-Safety Assertion (Must ONLY run inside VirtualBox VM)
# -----------------------------------------------------------------------------
try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
}
catch {
    Write-Error "[FAIL] Unable to query Win32_ComputerSystem: $_"
    exit 1
}

if ($cs.Model -notmatch "VirtualBox") {
    Write-Error "[FAIL] Host execution protection triggered: System Model is '$($cs.Model)'. This script is restricted to VirtualBox guest VMs only."
    exit 1
}

# -----------------------------------------------------------------------------
# 2. Helper Functions
# -----------------------------------------------------------------------------
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$normalizedExpected = $ExpectedThumbprint.Replace(" ", "").Replace(":", "").Trim().ToUpper()
$labRoot=New-Object Security.Cryptography.X509Certificates.X509Certificate2($RootCertPath)
$labSha=[Security.Cryptography.SHA256]::Create()
$labHash=([BitConverter]::ToString($labSha.ComputeHash($labRoot.RawData))).Replace('-','')
if($normalizedExpected -ne $labRoot.Thumbprint -and $normalizedExpected -ne $labHash){throw 'Pinned root mismatch'}

function Get-CertSha256Hex {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($Certificate.RawData)
    return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToUpper()
}

function Test-CertStorePresence {
    param(
        [string]$StorePath,
        [string]$ExpectedHash
    )

    $found = @()
    if (Test-Path $StorePath) {
        $certs = Get-ChildItem -Path $StorePath -ErrorAction SilentlyContinue
        foreach ($cert in $certs) {
            $sha1 = $cert.Thumbprint.ToUpper()
            $sha256 = Get-CertSha256Hex -Certificate $cert

            if ($sha1 -eq $ExpectedHash -or $sha256 -eq $ExpectedHash) {
                $found += [ordered]@{
                    Subject       = $cert.Subject
                    Issuer        = $cert.Issuer
                    Thumbprint    = $sha1
                    Thumbprint256 = $sha256
                    NotBefore     = $cert.NotBefore.ToString("o")
                    NotAfter      = $cert.NotAfter.ToString("o")
                    SerialNumber  = $cert.SerialNumber
                }
            }
        }
    }

    return [ordered]@{
        StorePath = $StorePath
        Present   = ($found.Count -gt 0)
        Matches   = $found
    }
}

function Invoke-TlsEndpointCheck {
    param([string]$Url)

    $record = [ordered]@{
        Url               = $Url
        TimestampUtc      = (Get-Date).ToUniversalTime().ToString("o")
        Success           = $false
        StatusCode        = $null
        StatusDescription = $null
        ErrorType         = $null
        ErrorMessage      = $null
        InnerError        = $null
    }

    try {
        # Strict validation: Do NOT bypass certificate validation!
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Proxy = $null
        $req.Timeout = 10000
        $req.Method = "GET"
        $resp = $req.GetResponse()
        $httpResp = [System.Net.HttpWebResponse]$resp

        $record.Success = $true
        $record.StatusCode = [int]$httpResp.StatusCode
        $record.StatusDescription = [string]$httpResp.StatusDescription
        $resp.Close()
    }
    catch [System.Net.WebException] {
        $ex = $_.Exception
        $record.ErrorType = "System.Net.WebException"
        $record.ErrorMessage = $ex.Message
        if ($ex.Response -ne $null) {
            $httpResp = [System.Net.HttpWebResponse]$ex.Response
            $record.StatusCode = [int]$httpResp.StatusCode
            $record.StatusDescription = [string]$httpResp.StatusDescription
        }
        if ($ex.InnerException -ne $null) {
            $record.InnerError = $ex.InnerException.Message
        }
    }
    catch {
        $record.ErrorType = $_.Exception.GetType().FullName
        $record.ErrorMessage = $_.Exception.Message
    }

    return $record
}

# -----------------------------------------------------------------------------
# 3. Action Execution
# -----------------------------------------------------------------------------
if (-not (Test-Path $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
}

$Endpoints = @(
    "https://10.20.30.10:8443/",
    "https://Tomcat-SSL:8443/"
)

switch ($Action) {
    "Import" {
        Write-Output "[INFO] Starting Import action for ${RootCertPath}..."
        if (-not (Test-Path $RootCertPath)) {
            Write-Error "[FAIL] Root certificate file does not exist at '${RootCertPath}'."
            exit 1
        }

        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($RootCertPath)
        $certSha1 = $cert.Thumbprint.ToUpper()
        $certSha256 = Get-CertSha256Hex -Certificate $cert

        Write-Output "[INFO] File Thumbprint SHA-1:   $certSha1"
        Write-Output "[INFO] File Thumbprint SHA-256: $certSha256"
        Write-Output "[INFO] Expected Thumbprint:     $normalizedExpected"

        $isMatch = ($certSha1 -eq $normalizedExpected) -or ($certSha256 -eq $normalizedExpected)
        if (-not $isMatch) {
            Write-Error "[FAIL] Pinned thumbprint mismatch! Provided thumbprint does not match rootCA.pem."
            exit 1
        }

        # Import ONLY into CurrentUser\Root (avoids mutating machine-wide store)
        # Note: Installing into CurrentUser Root may trigger an interactive Windows Security Warning dialog.
        # The coordinator will manage any dialog or GUI confirmation.
        Write-Output "[INFO] Pinned thumbprint verified. Importing certificate into CurrentUser\Root store..."
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($cert)
        $store.Close()

        # Verify whether the certificate is now present in the store
        $presence = Test-CertStorePresence -StorePath "Cert:\CurrentUser\Root" -ExpectedHash $normalizedExpected
        $importRecord = [ordered]@{
            Action            = "Import"
            TimestampUtc      = (Get-Date).ToUniversalTime().ToString("o")
            Hostname          = $env:COMPUTERNAME
            ThumbprintSha1    = $certSha1
            ThumbprintSha256  = $certSha256
            ImportCompleted   = $presence.Present
            StoreVerification = $presence
        }

        $jsonFile = Join-Path $ResultsDir "client-check-Import.json"
        $importRecord | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFile -Encoding UTF8
        Write-Output "[INFO] Import action finished. Result written to ${jsonFile}."
    }

    "Remove" {
        Write-Output "[INFO] Starting Remove action for matching root CA..."
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $toRemove = @()
        foreach ($c in $store.Certificates) {
            $cSha1 = $c.Thumbprint.ToUpper()
            $cSha256 = Get-CertSha256Hex -Certificate $c
            if ($cSha1 -eq $normalizedExpected -or $cSha256 -eq $normalizedExpected) {
                $toRemove += $c
            }
        }

        $removeCount = 0
        foreach ($c in $toRemove) {
            Write-Output "[INFO] Removing certificate: $($c.Subject) ($($c.Thumbprint))"
            $store.Remove($c)
            $removeCount++
        }
        $store.Close()

        # Record post-removal state
        $presenceUser = Test-CertStorePresence -StorePath "Cert:\CurrentUser\Root" -ExpectedHash $normalizedExpected
        $presenceMachine = Test-CertStorePresence -StorePath "Cert:\LocalMachine\Root" -ExpectedHash $normalizedExpected

        $testResults = @()
        foreach ($url in $Endpoints) {
            $testResults += (Invoke-TlsEndpointCheck -Url $url)
        }

        $report = [ordered]@{
            Action             = "Remove"
            TimestampUtc       = (Get-Date).ToUniversalTime().ToString("o")
            Hostname           = $env:COMPUTERNAME
            CurrentUser        = $env:USERNAME
            Model              = $cs.Model
            RemovedCount       = $removeCount
            CurrentUserRoot    = $presenceUser
            LocalMachineRoot   = $presenceMachine
            EndpointTlsTests   = $testResults
        }

        $jsonFile = Join-Path $ResultsDir "client-check-Remove.json"
        $report | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFile -Encoding UTF8
        Write-Output "[INFO] Remove action finished (${removeCount} removed). Result written to ${jsonFile}."
    }

    Default {
        # Before or After action: Record presence, test endpoints, output JSON
        Write-Output "[INFO] Executing Action '${Action}'..."
        $presenceUser = Test-CertStorePresence -StorePath "Cert:\CurrentUser\Root" -ExpectedHash $normalizedExpected
        $presenceMachine = Test-CertStorePresence -StorePath "Cert:\LocalMachine\Root" -ExpectedHash $normalizedExpected

        Write-Output "[INFO] Testing TLS endpoints (strict certificate validation active)..."
        $testResults = @()
        foreach ($url in $Endpoints) {
            Write-Output "[INFO] Probing $url ..."
            $testResults += (Invoke-TlsEndpointCheck -Url $url)
        }

        $report = [ordered]@{
            Action             = $Action
            TimestampUtc       = (Get-Date).ToUniversalTime().ToString("o")
            Hostname           = $env:COMPUTERNAME
            CurrentUser        = $env:USERNAME
            Model              = $cs.Model
            ExpectedThumbprint = $normalizedExpected
            CurrentUserRoot    = $presenceUser
            LocalMachineRoot   = $presenceMachine
            EndpointTlsTests   = $testResults
        }

        $jsonFile = Join-Path $ResultsDir "client-check-${Action}.json"
        $report | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFile -Encoding UTF8
        Write-Output "[INFO] Action '${Action}' complete. Results written to ${jsonFile}."
    }
}
