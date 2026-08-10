# One-shot iPhone deploy for vinodex-ios. Run UNELEVATED, from PowerShell.
#
#   .\scripts\deploy-iphone.ps1              # preflight -> sync -> build -> install
#   .\scripts\deploy-iphone.ps1 -CheckOnly   # preflight only, change nothing
#   .\scripts\deploy-iphone.ps1 -Clean       # rm -rf .build first (proves VinodexUI compiles)
#   .\scripts\deploy-iphone.ps1 -SkipSync    # WSL mirror is already current
#
# Everything here is deliberately ordered so that a failure is diagnosed BEFORE
# a ten-minute build is spent on it. See KNOWN-ISSUES.md "Deploying to the
# iPhone" for the reasoning behind each gate.
#
# Exit codes: 2 port unhealthy, 3 no WSL default route, 4 no device,
#             5 sync failed, 6 phone never trusted this computer,
#             7 phone not connected to Apple Devices,
#             otherwise xtool's own exit code.
#
# The proven opening sequence, when the bridge is down: replug the phone, run
# fix-27015.ps1 ELEVATED (it relaunches Apple Devices itself, in the order that
# wins the port race), then run this script with -SkipSync. Do not open Apple
# Devices by hand first - see step 0.
#
# This script never elevates. When the 27015 race needs fixing it prints the
# elevated command and stops - splitting the fix across a UAC prompt from
# inside a running deploy is exactly how the race is lost.
#
# ASCII only, on purpose: Windows PowerShell 5.1 reads this file as ANSI, and a
# stray em-dash inside a string is a parser error, not a cosmetic problem.

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$Clean,
    [switch]$SkipSync
)

$ErrorActionPreference = 'Stop'

$Distro  = 'xtool-ubuntu'
$WinRepo = 'H:\vscode-projects\HGapps\vinodex-ios'
$WslSrc  = '/mnt/h/vscode-projects/HGapps/vinodex-ios/'
$WslDst  = '/root/projects/vinodex-ios'

function Step($n, $text) { Write-Host "`n[$n] $text" -ForegroundColor Cyan }
function Ok($text)       { Write-Host "    OK  $text" -ForegroundColor Green }
function Bad($text)      { Write-Host "    !!  $text" -ForegroundColor Red }
function Note($text)     { Write-Host "    --  $text" -ForegroundColor DarkGray }

# Run a command in the WSL distro. Keep $Cmd free of $(...) and of quoted
# alternations like grep -E "a|b" - wsl.exe -- bash -lc silently mangles both,
# and an empty variable downstream is a much worse failure than a syntax error.
function Wsl($Cmd) { wsl.exe -d $Distro -- bash -lc $Cmd }

# ---------------------------------------------------------- 0. the connection
#
# The opening move, always: is Windows actually talking to the phone through
# Apple Devices? Every later gate assumes it. Apple Devices is not optional
# scaffolding - it IS the usbmuxd provider, so if it is closed there is nothing
# on the other end of the bridge no matter how healthy the port looks.

Step 0 'Phone connected to Apple Devices'

$usb = @(Get-PnpDevice -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -match 'Apple Mobile Device USB|Apple iPhone' -and $_.Status -eq 'OK' })

if (-not $usb) {
    Bad 'Windows does not see the phone on USB.'
    Note 'Unplug, replug, unlock the phone, then re-run.'
    Note 'A node stuck at status Unknown usually means a replug in progress.'
    exit 7
}
Ok "$($usb.Count) Apple USB node(s) enumerated."

$appleProcs = @(Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -match 'Apple|AMPDevices' })

if (-not $appleProcs) {
    Bad 'Apple Devices is not running - it IS the usbmuxd provider.'
    Note 'Do NOT simply open it. While the portproxy still holds 27015, Apple'
    Note 'cannot bind 127.0.0.1:27015, falls back to an ephemeral port, and'
    Note 'starts respawning every 30-60s - which outruns the fix.'
    Note 'Run the elevated fix instead. It frees the port, relaunches Apple'
    Note 'Devices in the right order, and re-adds the proxy only if Apple won:'
    Write-Host "  Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy','Bypass','-File','$WinRepo\scripts\fix-27015.ps1'" -ForegroundColor Yellow
    exit 7
}
Ok 'Apple Devices is running.'

# ---------------------------------------------------------------- 1. the port

Step 1 'Port 27015 (usbmuxd bridge)'

$listeners = @(Get-NetTCPConnection -LocalPort 27015 -State Listen -ErrorAction SilentlyContinue |
    ForEach-Object {
        [pscustomobject]@{
            Address = $_.LocalAddress
            Process = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        }
    })

foreach ($l in $listeners) { Note ("{0,-9} <- {1}" -f $l.Address, $l.Process) }

$apple = $listeners | Where-Object { $_.Address -eq '127.0.0.1' -and $_.Process -match 'Apple|AMPDevices' }
$proxy = $listeners | Where-Object { $_.Address -eq '0.0.0.0' }

# The tell for the lost race: Apple fell back to an ephemeral port. Connecting
# to that port succeeds and speaks the wrong protocol, so it reads as healthy.
$ephemeral = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalAddress -eq '127.0.0.1' -and $_.LocalPort -gt 10000 } |
    Where-Object { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName -match 'Apple|AMPDevices' })

if (-not ($apple -and $proxy)) {
    Bad 'Unhealthy. Want BOTH 127.0.0.1 <- Apple* and 0.0.0.0 <- svchost.'
    if (-not $apple -and $proxy) { Note 'The portproxy won the race; Apple has no 27015.' }
    if ($apple -and -not $proxy) { Note 'Apple holds the port but the portproxy is missing; WSL cannot reach it.' }
    if (-not $listeners)         { Note 'Nothing listening at all - the Apple Devices app is probably closed.' }
    foreach ($e in $ephemeral) {
        Note ("Apple is on ephemeral 127.0.0.1:{0} - confirms the proxy won. Do NOT point USBMUXD at it." -f $e.LocalPort)
    }
    Write-Host "`nRun this, approve the UAC prompt, then re-run this script:" -ForegroundColor Yellow
    Write-Host "  Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy','Bypass','-File','$WinRepo\scripts\fix-27015.ps1'"
    exit 2
}
Ok 'Both listeners present.'

# ------------------------------------------------------------- 2. the gateway

Step 2 'WSL gateway'

# Resolved on the Windows side on purpose: `ip -o route` inside bash -lc with a
# $(...) around it comes back empty, and xtool then hangs instead of erroring.
$routes = Wsl 'ip -o route'
$match  = $routes | Select-String -Pattern '^default via (\S+)'
if (-not $match) { Bad 'No default route in the distro.'; exit 3 }
$gateway = $match.Matches[0].Groups[1].Value
$usbmuxd = "${gateway}:27015"
Ok "USBMUXD_SOCKET_ADDRESS=$usbmuxd"

# -------------------------------------------------------------- 3. the device

Step 3 'Device visibility'

# `timeout` converts the classic silent hang into a real failure.
$udid = (Wsl "timeout 25 env USBMUXD_SOCKET_ADDRESS=$usbmuxd idevice_id -l") -join "`n"
if (-not $udid.Trim()) {
    Bad 'No device. TCP is up but usbmuxd returned nothing.'
    Note 'Phone plugged in, UNLOCKED, and trusting this computer?'
    Note 'Apple Devices app open and showing the phone?'
    Note 'Pairing record: C:\ProgramData\Apple\Lockdown\<UDID>.plist'
    Note 'If all of that is true, the port race is in its silent state - run fix-27015.ps1 elevated.'
    exit 4
}
Ok "UDID $($udid.Trim())"

# ------------------------------------------------------------ 3b. the pairing
#
# The computer recognising the phone comes FIRST, before any build is spent.
# idevice_id lists a device over raw usbmuxd whether or not it is trusted, so a
# green step 3 is not evidence of trust. Everything downstream - provisioning,
# install, launch - is a lockdown conversation that needs the pairing record,
# and those fail LATE, after the build. Ask for trust up front instead.

Step '3b' 'Trust / pairing'

$pairEnv  = "env USBMUXD_SOCKET_ADDRESS=$usbmuxd"
$validate = (Wsl "timeout 20 $pairEnv idevicepair validate 2>&1") -join "`n"

if ($validate -match 'SUCCESS') {
    Ok 'Phone is paired and trusting this computer.'
} else {
    Note 'Not validated - asking the phone to trust this computer now.'
    Note 'UNLOCK the phone and tap Trust when the dialog appears.'

    $pair = (Wsl "timeout 30 $pairEnv idevicepair pair 2>&1") -join "`n"
    foreach ($line in ($pair -split "`n")) { if ($line.Trim()) { Note $line.Trim() } }

    # Poll rather than assume: the dialog waits on a human, and pair returns
    # before the phone has answered it.
    $trusted = $false
    foreach ($i in 1..20) {
        Start-Sleep -Seconds 3
        $validate = (Wsl "timeout 20 $pairEnv idevicepair validate 2>&1") -join "`n"
        if ($validate -match 'SUCCESS') { $trusted = $true; break }
    }

    if (-not $trusted) {
        Bad 'The phone never accepted the trust dialog.'
        Note 'Unlock it, tap Trust, then re-run this script.'
        Note 'No dialog at all? Settings > General > Transfer or Reset iPhone >'
        Note 'Reset > Reset Location & Privacy, then unplug/replug and retry.'
        exit 6
    }
    Ok 'Trust accepted.'
}

if ($CheckOnly) { Write-Host "`nPreflight clean - ready to deploy." -ForegroundColor Green; exit 0 }

# ---------------------------------------------------------------- 4. the sync

if (-not $SkipSync) {
    Step 4 'Sync WSL mirror'
    Wsl "rsync -a --delete --exclude '.build/' --exclude 'xtool/' --exclude '.git/' $WslSrc $WslDst/"
    if ($LASTEXITCODE -ne 0) { Bad "rsync exit $LASTEXITCODE"; exit 5 }

    # Separate invocation: drvfs metadata is stale within the run that wrote it.
    $winCount = (Get-ChildItem -Path "$WinRepo\Sources" -Recurse -Filter *.swift).Count
    $wslCount = [int](((Wsl "find $WslDst/Sources -name '*.swift' | wc -l") -join '').Trim())
    if ($winCount -ne $wslCount) { Bad "Mirror mismatch: $winCount swift files here, $wslCount there."; exit 5 }
    Ok "$wslCount Swift files mirrored."
} else {
    Step 4 'Sync WSL mirror - skipped (-SkipSync)'
}

# --------------------------------------------------------------- 5. the build

if ($Clean) { Step 5 'Build + install (clean)' } else { Step 5 'Build + install' }

# Measured, so nobody has to sit and watch it. Clean build: ~300s at v0.9.0
# size (was 210-230s pre-reorg). Warm build: under 10s. Install after the
# build: well under a minute. Check back near the end of that window rather
# than polling the whole way through.
if ($Clean) {
    Note 'Clean build: expect ~300s, then install. Check back at ~5.5 min.'
} else {
    Note 'Warm build: under 10s, then install. Expect this within a minute.'
}

if ($Clean) { Wsl "rm -rf $WslDst/.build" }

Wsl "cd $WslDst && USBMUXD_SOCKET_ADDRESS=$usbmuxd xtool dev run"
$code = $LASTEXITCODE

Write-Host ''
if ($code -eq 0) {
    Write-Host 'Deployed. Free-profile signing expires 7 days from now.' -ForegroundColor Green
} else {
    Bad "xtool dev run exit $code"
    Note 'ApplicationVerificationFailed / max apps -> App ID quota is 3; keep bundle id com.example.Vinodex.'
    Note 'Operation not permitted                  -> the port race flipped mid-run; fix-27015.ps1, then -SkipSync.'
    Note 'Swift errors                             -> re-run with -Clean; a warm .build hides UI breakage.'
}
exit $code
