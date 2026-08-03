# Free port 27015 for Apple's usbmuxd, then put the WSL portproxy back in front
# of it. See KNOWN-ISSUES.md, "The 27015 port race".
#
# RUN ELEVATED, and run the WHOLE thing in one go. The fix must not be split
# across a UAC prompt: when Apple's launcher is in its ephemeral-port state it
# respawns every 30-60s on a new port, so discover -> prompt -> use always loses
# the race.
#
# Step 2 launches a Store app, which refuses to start elevated — so it is
# dispatched through explorer.exe, which runs as the logged-in user even when
# this script does not.

$ErrorActionPreference = 'Continue'

function Show-Listeners {
    Get-NetTCPConnection -LocalPort 27015 -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object {
            "{0} <- {1}" -f $_.LocalAddress, (Get-Process -Id $_.OwningProcess).ProcessName
        }
}

Write-Host "Before:" -ForegroundColor Cyan
Show-Listeners

# 1. Free the port: drop the proxy, stop Apple's side.
netsh interface portproxy delete v4tov4 listenport=27015 listenaddress=0.0.0.0 | Out-Null
Get-Process | Where-Object { $_.ProcessName -match 'Apple|AMPDevices' } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 2. Bring Apple back up FIRST, so it wins 127.0.0.1:27015 this time.
#    Via explorer so the Store app launches unelevated.
explorer.exe 'shell:AppsFolder\AppleInc.AppleDevices_nzyj5cx40ttqa!App'

$ok = $false
foreach ($i in 1..20) {
    Start-Sleep -Seconds 1
    $apple = Get-NetTCPConnection -LocalPort 27015 -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalAddress -eq '127.0.0.1' }
    if ($apple) { $ok = $true; break }
}

if (-not $ok) {
    Write-Host "Apple never took 127.0.0.1:27015 - do NOT re-add the proxy yet." -ForegroundColor Red
    Write-Host "Open the Apple Devices app by hand, confirm the phone appears, then re-run." -ForegroundColor Red
    Show-Listeners
    exit 1
}

# 3. Only now put the proxy back in front of it.
netsh interface portproxy add v4tov4 listenport=27015 listenaddress=0.0.0.0 `
    connectport=27015 connectaddress=127.0.0.1 | Out-Null

Write-Host "`nAfter (want BOTH lines):" -ForegroundColor Cyan
Show-Listeners
Write-Host "`n  127.0.0.1 <- AppleMobileDeviceProcess (or AMPDevicesAgent)"
Write-Host "  0.0.0.0   <- svchost"
Write-Host "`nThen, from an ordinary PowerShell:" -ForegroundColor Cyan
Write-Host '  wsl.exe -d xtool-ubuntu -- bash -lc "cd /root/projects/vinodex-ios && USBMUXD_SOCKET_ADDRESS=172.20.80.1:27015 xtool dev run"'
Write-Host "  (verify the gateway first with: wsl.exe -d xtool-ubuntu -- ip -o route)"
