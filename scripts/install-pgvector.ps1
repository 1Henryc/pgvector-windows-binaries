#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Secure installer for precompiled pgvector binaries on Windows.

.DESCRIPTION
Downloads the release ZIP from 1Henryc/pgvector-windows-binaries, verifies its
SHA-256 checksum against the entry for that exact file, validates the archive
contents, and installs them into the selected PostgreSQL directory.

.EXAMPLE
.\install-pgvector.ps1 -Version v0.8.7 -PgVersion 17 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidatePattern('^v\d+\.\d+\.\d+(-win\.\d+)?$')]
    [string]$Version = 'v0.8.7',

    [ValidateSet(16, 17, 18)]
    [int]$PgVersion,

    [string]$PgRoot,

    [string]$Repo = '1Henryc/pgvector-windows-binaries'
)


$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "`n[+] Installing pgvector $Version..." -ForegroundColor Cyan

# 1. Resolve the PostgreSQL installation
if (-not $PgRoot) {
    $pgBase = Join-Path $env:ProgramFiles 'PostgreSQL'
    if (-not (Test-Path $pgBase)) {
        throw "PostgreSQL not found at '$pgBase'. Use -PgRoot to specify a custom location."
    }

    $found = @(Get-ChildItem $pgBase -Directory |
        Where-Object { $_.Name -match '^\d+$' } |
        Select-Object -ExpandProperty Name)

    if ($found.Count -eq 0) { throw "No PostgreSQL versions detected in '$pgBase'." }

    if ($PSBoundParameters.ContainsKey('PgVersion')) {
        $target = [string]$PgVersion
        if ($found -notcontains $target) {
            throw "PostgreSQL $target is not installed. Found: $($found -join ', ')."
        }
    }
    elseif ($found.Count -eq 1) {
        $target = $found[0]
    }
    else {
        throw "Multiple PostgreSQL versions found ($($found -join ', ')). Specify -PgVersion."
    }
    $PgRoot = Join-Path $pgBase $target
}
else {
    $target = Split-Path $PgRoot -Leaf
}

if (-not (Test-Path (Join-Path $PgRoot 'bin\postgres.exe'))) {
    throw "'$PgRoot' does not look like a valid PostgreSQL installation."
}
if ($target -notmatch '^(16|17|18)$') {
    throw "PostgreSQL $target is not supported by these binaries (supported: 16, 17, 18)."
}
Write-Host " -> Target: PostgreSQL $target ($PgRoot)" -ForegroundColor Green

# 2. Build URLs
$zipName     = "pgvector-$Version-pg$target-windows-x64.zip"
$baseUrl     = "https://github.com/$Repo/releases/download/$Version"
$tempDir     = Join-Path ([IO.Path]::GetTempPath()) "pgvector_install_$([guid]::NewGuid())"
$tempZip     = Join-Path $tempDir $zipName
$tempHash    = Join-Path $tempDir 'SHA256SUMS.txt'
$extractPath = Join-Path $tempDir 'extracted'

New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    # 3. Download
    Write-Host " -> Downloading $zipName..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "$baseUrl/$zipName"         -OutFile $tempZip  -UseBasicParsing
    Invoke-WebRequest -Uri "$baseUrl/SHA256SUMS.txt"   -OutFile $tempHash -UseBasicParsing

    # 4. Verify checksum against the entry for this exact file
    Write-Host " -> Verifying SHA-256 checksum..." -ForegroundColor Yellow
    $actual = (Get-FileHash -Path $tempZip -Algorithm SHA256).Hash.ToLowerInvariant()

    $expected = $null
    foreach ($line in Get-Content -Path $tempHash) {
        if ($line -match '^(?<hash>[0-9a-fA-F]{64})\s+\*?(?<name>\S+)\s*$' -and
            $Matches['name'] -ceq $zipName) {
            $expected = $Matches['hash'].ToLowerInvariant()
            break
        }
    }

    if (-not $expected) { throw "No checksum entry found for '$zipName' in SHA256SUMS.txt." }
    if ($actual -ne $expected) {
        throw "Checksum mismatch for '$zipName'. Expected $expected but got $actual. Aborting."
    }
    Write-Host "    [OK] Checksum matches." -ForegroundColor Green

    # 5. Extract and validate contents (whitelist)
    Expand-Archive -Path $tempZip -DestinationPath $extractPath -Force

    $dll     = Join-Path $extractPath 'lib\vector.dll'
    $control = Join-Path $extractPath 'share\extension\vector.control'
    $sqlFiles = @(Get-ChildItem (Join-Path $extractPath 'share\extension') -Filter 'vector--*.sql' -ErrorAction SilentlyContinue)

    if (-not (Test-Path $dll))     { throw "Archive is missing lib\vector.dll." }
    if (-not (Test-Path $control)) { throw "Archive is missing vector.control." }
    if ($sqlFiles.Count -eq 0)     { throw "Archive contains no vector--*.sql files." }

    # 6. Install
    if ($PSCmdlet.ShouldProcess($PgRoot, "Install pgvector $Version")) {
        Write-Host " -> Installing files..." -ForegroundColor Yellow
        try {
            Copy-Item $dll     -Destination (Join-Path $PgRoot 'lib')             -Force
            Copy-Item $control -Destination (Join-Path $PgRoot 'share\extension') -Force
            $sqlFiles | Copy-Item -Destination (Join-Path $PgRoot 'share\extension') -Force
        }
        catch [System.IO.IOException] {
            throw "Could not overwrite files (vector.dll may be in use). Restart the PostgreSQL service and retry. Details: $($_.Exception.Message)"
        }

        Write-Host "`n pgvector $Version installed successfully." -ForegroundColor Green
        Write-Host " Enable it in your database with:  CREATE EXTENSION vector;" -ForegroundColor Cyan
    }
}
finally {
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}