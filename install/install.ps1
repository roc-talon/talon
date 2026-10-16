#requires -version 5.1
<#
Talon installer for Windows. Rules: DESIGN-CLI.md 6.5 (R-S1, R-IS1 to R-IS8).

    irm https://github.com/roc-talon/talon/releases/latest/download/install.ps1 | iex
    & ([scriptblock]::Create((irm .../install.ps1))) -Version 0.3.1     (repair, R-S4)

Downloads the prebuilt tln.exe for this machine, checks its sha256, puts it in the tool
bin dir, then runs `tln setup`. With `irm | iex` there are no arguments, so each parameter
also has an environment variable: TALON_VERSION, TALON_YES, TALON_NO_MODIFY_PATH.
The structure follows the rocup installer (github.com/imclerran/rocup).
#>
param(
    [string] $Version = $env:TALON_VERSION,
    [switch] $Yes = ($env:TALON_YES -eq '1'),
    [switch] $NoModifyPath = ($env:TALON_NO_MODIFY_PATH -eq '1')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$Repo = if ($env:TALON_REPO) { $env:TALON_REPO } else { 'roc-talon/talon' }
# Base URL of the release assets. Tests and mirrors set TALON_DOWNLOAD_BASE.
$Base = if ($env:TALON_DOWNLOAD_BASE) { $env:TALON_DOWNLOAD_BASE } else { "https://github.com/$Repo/releases" }

# With `irm | iex` the script runs in the shell of the user, and `exit` would close that
# shell. So only a run from a file exits with a Talon exit code. Else the error is thrown.
function Fail([string] $Message, [int] $Code = 1) {
    if ($PSCommandPath) {
        [Console]::Error.WriteLine("install.ps1: error: $Message")
        exit $Code
    }
    throw "install.ps1: error: $Message"
}

# Roc target name of this machine (R-IS2)
function Get-Target {
    $arch = $env:PROCESSOR_ARCHITEW6432 # set when a 32-bit shell runs on a 64-bit system
    if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
    switch ($arch) {
        'AMD64' { return 'x64win' }
        'ARM64' {
            # basic-cli has no arm64win target. Windows 11 on ARM64 runs x64 binaries by emulation.
            Write-Host 'note: no native Windows ARM64 build of tln. Installing the x64 build, which runs by emulation.'
            return 'x64win'
        }
        default { Fail "no prebuilt tln for Windows on $arch. Prebuilt target: x64win." }
    }
}

# Same rules as tln (DESIGN-CLI.md 4)
function Test-Interactive {
    switch ($env:TALON_INTERACTIVE) {
        '0' { return $false }
        '1' { }
        default {
            if ("$env:CI" -match '^(true|1)$') { return $false }
            if ($env:DEBIAN_FRONTEND -eq 'noninteractive') { return $false }
            if ("$env:NONINTERACTIVE" -match '^(1|true)$') { return $false }
        }
    }
    return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not [Console]::IsErrorRedirected
}

$Target = Get-Target
$Asset = "tln-$Target.exe"
$Version = "$Version".TrimStart('v')
if ($Version) { $Url = "$Base/download/v$Version"; $Label = "Talon $Version" }
else { $Url = "$Base/latest/download"; $Label = 'the newest Talon release' }
$Data = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'talon' } else { Fail 'LOCALAPPDATA is not set' }
$Bin = Join-Path $Data 'bin'

Write-Host "This installs $Label ($Asset) from ${Repo}:"
Write-Host "  - tln.exe goes in $Bin"
Write-Host "  - tln setup then adds tln, the roc launcher and completions to $(Join-Path $HOME '.local\bin'),"
Write-Host "    and that directory to your user PATH (DESIGN-CLI.md 6.7)"
if (-not $Yes) {
    if (Test-Interactive) {
        $reply = Read-Host 'Proceed? [Y/n]'
        if ($reply -match '^(n|no)$') { Fail 'cancelled' }
    }
    else { Write-Host 'Non-interactive mode: no prompt (the command names the install).' }
}

New-Item -ItemType Directory -Path $Bin -Force | Out-Null
# Download next to the final path, so the last step is a rename on one volume (R-IS5)
$Tmp = Join-Path $Bin (".tln.{0}.exe" -f [Guid]::NewGuid().ToString('N'))
$Sums = Join-Path $Bin (".sums.{0}" -f [Guid]::NewGuid().ToString('N'))
$oldProgress = $ProgressPreference
$ProgressPreference = 'SilentlyContinue' # the progress bar makes Invoke-WebRequest slow on 5.1
try {
    Write-Host "downloading $Url/$Asset"
    try {
        Invoke-WebRequest -Uri "$Url/$Asset" -OutFile $Tmp -UseBasicParsing
        Invoke-WebRequest -Uri "$Url/sha256sums.txt" -OutFile $Sums -UseBasicParsing
    }
    catch { Fail "download failed: $($_.Exception.Message)" 15 }
    $ProgressPreference = $oldProgress

    $want = $null
    foreach ($line in Get-Content -LiteralPath $Sums) {
        $f = $line -split '\s+', 2
        if ($f.Count -eq 2 -and ($f[1] -eq $Asset -or $f[1] -eq "*$Asset")) { $want = $f[0].ToLowerInvariant() }
    }
    if (-not $want) { Fail "sha256sums.txt has no line for $Asset" 16 }
    $got = (Get-FileHash -LiteralPath $Tmp -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($got -ne $want) { Fail "sha256 mismatch for ${Asset}: expected $want, got $got" 16 }
    Write-Host "sha256 ok ($got)"

    # Attestation (R-S1): only when gh is installed and logged in
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    $ghOk = $false
    if ($gh) { & gh auth status *> $null; $ghOk = ($LASTEXITCODE -eq 0) }
    if ($ghOk) {
        & gh attestation verify $Tmp --repo $Repo *> $null
        if ($LASTEXITCODE -ne 0) { Fail "attestation check failed for $Asset" 16 }
        Write-Host 'attestation ok'
    }
    else { Write-Host 'note: attestation not checked (needs gh, logged in)' }

    # A binary that does not start never replaces a working one (R-S3)
    $ver = & $Tmp --version 2>$null
    if ($LASTEXITCODE -ne 0) { Fail 'the downloaded tln does not start on this machine' }
    $Exe = Join-Path $Bin 'tln.exe'
    if (Test-Path -LiteralPath $Exe) {
        # A running tln.exe cannot be overwritten, but it can be renamed (R-S3). The R-ST10 name
        # tln.<16hex>.del lets the next tln start delete it when the delete below fails.
        $Old = Join-Path $Bin ("tln.{0}.del" -f [Guid]::NewGuid().ToString('N').Substring(0, 16))
        Move-Item -LiteralPath $Exe -Destination $Old
        Remove-Item -LiteralPath $Old -Force -ErrorAction SilentlyContinue
    }
    Move-Item -LiteralPath $Tmp -Destination $Exe
    Write-Host "installed $ver at $Exe"
}
finally {
    $ProgressPreference = $oldProgress
    Remove-Item -LiteralPath $Tmp, $Sums -Force -ErrorAction SilentlyContinue
}

# tln setup writes the talon entry of tools.json and connects the shell (R-IS6)
$SetupArgs = @('setup')
if ($Yes) { $SetupArgs += '--yes' }
if ($NoModifyPath) { $SetupArgs += '--no-modify-path' }
& $Exe @SetupArgs
if ($PSCommandPath) { exit $LASTEXITCODE }
