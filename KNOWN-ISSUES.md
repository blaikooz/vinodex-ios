# Known issues & environment runbook

> ## 2026-09-01 — simulator state lies between sessions; the full /dispatch ceremony is proven
>
> **Never trust "the simulator is already booted".** A sim that was booted in a
> previous session can be `Shutdown` by the time you act, and `simctl install`
> against it fails with exit 149 / `Unable to lookup in current state: Shutdown`
> (CoreSimulator error 405). Booting is cheap and near-idempotent, so always run
> `xcrun simctl boot <UDID>` then `xcrun simctl bootstatus <UDID>` (blocks until
> the sim is actually usable, ~10 s cold) before install/launch — the reasoning:
> checking the claimed state costs more than just re-establishing it.
>
> **The scripted dispatch (tag → generate → archive → export-upload) works
> end-to-end as written** — first proven run 2026-09-01, v0.9.44 (219): archive
> ~1 min, export+upload ~2 min, `EXPORT SUCCEEDED` / `Upload succeeded` with the
> ASC key and the `PATH="/usr/bin:$PATH"` prefix, no Organizer involved.

> ## 2026-08-28 — this repo moved to a Mac mini; the WSL/xtool runbook below is historical
>
> The whole workspace moved from the Windows PC (`H:\vscode-projects\HGapps`,
> WSL2 distro `xtool-ubuntu`, iPhone over TCP usbmuxd on port 27015) to a Mac
> mini at `~/Developer/HGapps` with **Xcode 26.6 / Swift 6.3.3** installed
> natively. Everything from [Deploying to the iPhone](#deploying-to-the-iphone)
> down to [Traps that produce false readings](#traps-that-produce-false-readings)
> describes the old machine and is kept as history — the reasoning in it
> (trust before build, cheap gates before expensive ones, "a threshold change
> that alters nothing means the event never arrived") still holds; the
> commands do not. Specifically:
>
> | Section | On the Mac |
> |---|---|
> | The 27015 port race, `fix-27015.ps1`, portproxy, states 1–3, `usbipd` | **Moot.** No WSL, no TCP bridge; usbmuxd is native. `scripts/fix-27015.ps1` and `scripts/deploy-iphone.ps1` are Windows-only and stay in the tree only as the record of what the pipeline was. |
> | Free-profile App ID cap · bundle-ID one-way door · 409 `ENTITY_ERROR` | **Still true** — these are Apple-side facts, not Windows ones. The account is paid and the ID is `com.blaikooz.vinodex`. |
> | `Multiple library products` / `xtool.yml` needs `product:` | Still true *if* xtool is used (xtool 1.17.0 is installed via Homebrew for that reason), but the Mac path is Xcode: open `Package.swift` in Xcode, or `xcodebuild`. |
> | `swift build` cannot see three-quarters of the app · `typecheck-ios-surface.sh` | **Still true, and now runnable** — `scripts/typecheck-ios-surface.sh` was written for a Mac and finally has one. The stronger gate is CI's own command, which also runs here: `xcodebuild build -scheme Vinodex -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`. |
> | The WSL mirror goes stale · `.gates.sh`, `.retest.sh`, `scripts/gate.sh`, `scripts/testonly.sh`, `scripts/build-log.sh` | **Moot.** There is no mirror: builds run against the checkout. Those five scripts hardcode `/mnt/h/...` and `/root/projects/...` and are dead here. |
> | `swift test` cannot see any UI code | **Half true.** `swift test` still tests `VinodexCore` only, but on this machine `xcodebuild test -scheme Vinodex-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'` runs `VinodexUITests` on a simulator (809 core + 17 UI tests as of 2026-08-28). |
> | `.contentShape` outside `.offset` · `rethrows` inside `#expect` · renamed-repo cache poison · xtool version stamp · Open bugs | **Still true** — SwiftUI, swift-testing and Actions facts. |
>
> **New on this machine (2026-08-28):** moving the checkout invalidates
> `.build` — the module cache bakes absolute paths in, and a moved tree fails
> with `module '_DarwinFoundation1' is defined in both ...` and a swift-frontend
> SIGSEGV. `rm -rf .build` and rebuild (clean `swift build` is ~8 s here). Same
> class as the renamed-repo Actions cache poison below.
>
> The Mac gates, in order: `swift build` → `swift test` →
> `bash scripts/typecheck-ios-surface.sh` → the `xcodebuild` build above →
> the simulator test above. Device deploy is Xcode's Run button or
> `xcodebuild` + `xcrun devicectl`; it has **not** been proven on this machine
> yet — see `HGapps/HANDOVER-MAC.md` and the `deploybot` agent charter.

> ## 2026-08-30 — TestFlight ships from this Mac; xtool and Codemagic retired
>
> The first Xcode-path release is **0.9.2 (195)**: `scripts/generate-xcodeproj.sh`
> → `xcodebuild archive -allowProvisioningUpdates` → Organizer → Distribute App.
> It reached `processingState: VALID` the same night, with none of the five
> patch steps the Codemagic pipeline needed (DT plist keys, actool icon
> catalog, vtool LC_BUILD_VERSION rewrite, PlistBuddy version stamp, hand
> re-sign) — Xcode does all of that itself, which is the whole argument for
> the migration. `xtool.yml` and `codemagic.yaml` are deleted; both live in
> git history at tag `v0.9.2` and earlier if the Linux path ever has to come back.
>
> **The version scheme, and its one rule.** `CFBundleShortVersionString` is the
> newest annotated tag (stripped `v`); `CFBundleVersion` is
> `git rev-list --count HEAD`. Both stamp at project *generation*, so:
> **commit, then tag, then generate, then archive.** TestFlight rejects a
> reused (version, build) pair, and the build number only moves with history —
> a re-archive of the same commit is a rejected upload, not a retry.
>
> **The tag/ref trigger trap (how an upload nearly fired anyway).** Codemagic
> reads `codemagic.yaml` from the ref it builds, not from HEAD. Disabling the
> `v*` tag trigger on a new commit does **not** defuse a tag pointing at an
> older commit — the old file rides the tag, live trigger and all. `v0.9.2`
> was created on the pre-disable commit and had to be deleted and re-created
> on the disable commit before it was safe to push. The general rule survives
> the retirement: a CI trigger is only as dead as the oldest ref that still
> carries it.
>
> **ASC API access from this Mac.** An App Store Connect API key lives in
> `~/.appstoreconnect/private_keys/` (created 2026-08-30, *Developer* role) —
> what the processing-state poll used, and what any future upload automation
> (`xcodebuild -exportArchive` with `-authenticationKeyPath`, or `altool`)
> should use. The key file downloads from ASC exactly once; if it is lost, a
> new key is minted rather than recovered.


Hard-won operational knowledge for this repo. Most of it is about getting a build
onto the phone from Windows + WSL, which is where the time actually goes.

- [Deploying to the iPhone](#deploying-to-the-iphone) — start here when a deploy fails
- [Traps that produce false readings](#traps-that-produce-false-readings)
- [Build & test gotchas](#build--test-gotchas)
- [Open bugs](#open-bugs)
- [Repo layout](#repo-layout)

---

## Deploying to the iPhone

### The 27015 port race — recurs on every reboot *and mid-session*

**The single most likely reason a deploy fails.**

It is not only a boot-time race. `AppleMobileDeviceProcess` exits when the Apple
Devices app is closed, and the portproxy then reclaims 27015 on its own — so a
deploy that worked an hour ago fails with `Operation not permitted` having
changed nothing. Same symptom, same fix, no reboot involved. Check which side
holds the port before assuming anything else:

```powershell
Get-NetTCPConnection -LocalPort 27015 -State Listen | ForEach-Object {
  "{0} <- {1}" -f $_.LocalAddress, (Get-Process -Id $_.OwningProcess).ProcessName
}
```

Healthy is **two** lines: `127.0.0.1 <- AppleMobileDeviceProcess` and
`0.0.0.0 <- svchost`. One line means run the fix below.

`netsh portproxy` binds `0.0.0.0:27015`, which *covers* `127.0.0.1`. Apple's
`AppleMobileDeviceProcess` also wants `127.0.0.1:27015`. **Whichever binds first
at boot wins**, and there is no error either way:

- Apple wins → everything works, both listeners coexist.
- The proxy wins → Apple silently falls back to an **ephemeral** port, and the
  proxy forwards to a dead 27015. WSL connects fine and then speaks to nothing.

Symptoms: `xtool devices` → `Error: Operation not permitted`, or
`idevice_id -l` → `ERROR: Unable to retrieve device list!`, while raw TCP to
`<gateway>:27015` reports **connected**. That combination — TCP OK, protocol
dead — is this bug.

**Fix, in this order.** Order is the whole point.

> **There is a script now: `scripts/fix-27015.ps1`** (added 0.7.1). Right-click
> → Run as administrator, or `Start-Process powershell -Verb RunAs -ArgumentList
> '-ExecutionPolicy','Bypass','-File','H:\vscode-projects\HGapps\vinodex-ios\scripts\fix-27015.ps1'`.
> It does all three steps in one elevated pass, dispatches step 2 through
> `explorer.exe` so the Store app still launches unelevated, waits up to 20s for
> Apple to take `127.0.0.1:27015`, and **refuses to re-add the proxy if Apple
> did not get it** — which is the failure the manual sequence below can walk
> straight past. The steps are kept here because the script is a transcription
> of them and the reasoning is what matters.
>
> **A note on `AMPDevicesAgent`.** The healthy listener is sometimes this
> rather than `AppleMobileDeviceProcess`; both are Apple's side and either is
> fine. What is *not* fine is seeing it listening on some five-digit port
> (`127.0.0.1:55095` and friends) — that is the ephemeral fallback, and it
> means the proxy won the race. Do not point `USBMUXD_SOCKET_ADDRESS` at it:
> it is the launcher's own IPC, not usbmuxd, so you connect fine and speak the
> wrong protocol.

```powershell
# 1. ELEVATED — free the port and stop Apple's processes
netsh interface portproxy delete v4tov4 listenport=27015 listenaddress=0.0.0.0
Get-Process | Where-Object { $_.ProcessName -match 'Apple' } | Stop-Process -Force

# 2. UNELEVATED — Store apps refuse to launch elevated
Start-Process 'shell:AppsFolder\AppleInc.AppleDevices_nzyj5cx40ttqa!App'
# within ~6s this must appear, or step 3 will just steal the port again:
Get-NetTCPConnection -LocalPort 27015 -State Listen |
  Where-Object { $_.LocalAddress -eq '127.0.0.1' }

# 3. ELEVATED — put the proxy back in front of it
netsh interface portproxy add v4tov4 listenport=27015 listenaddress=0.0.0.0 `
  connectport=27015 connectaddress=127.0.0.1
```

Healthy end state — **both** listeners present:

```
127.0.0.1:27015   AppleMobileDeviceProcess
0.0.0.0:27015     svchost   (the portproxy)
```

Then `idevice_id -l` returns the UDID and `xtool dev run` works.

> The Store `AppleInc.AppleDevices` package **does** provide usbmuxd on 27015.
> Classic iTunes / Apple Mobile Device Support is **not** required — only the
> `AppleKmdfFilter` / `AppleLowerFilter` drivers, which are already installed.
> Don't go installing desktop iTunes to "fix" this.

### Never split the fix across a UAC prompt

Each elevation round-trip is ~10 s. When Apple's launcher is in its ephemeral-port
state it respawns every ~30–60 s with a **new** port each time, so anything that
discovers a port, prompts for UAC, then uses that port is guaranteed to lose the
race. Do discover → `netsh` → verify inside **one** elevated script.

Also: chasing the ephemeral port is a dead end regardless. The port
`AppleMobileDeviceLauncher` opens is its own IPC, not usbmuxd — you connect
successfully and get the wrong protocol. Free 27015 instead.

### The ephemeral listener is a *sometimes* tell, not a required confirmation

Observed 2026-08-03: the port in the broken state with **no Apple process running
at all** — `0.0.0.0:27015 <- svchost` alone, nothing on any `127.0.0.1` port, and
`Get-Process | ? ProcessName -match 'Apple|AMPDevices'` returning empty.

This matters because the section above teaches the ephemeral five-digit port as
*the* confirmation, and it is easy to go looking for it, not find it, and start
doubting the 27015 diagnosis — then go hunting for a second, non-existent cause.
There are two distinct broken sub-states and only the first has an ephemeral port:

1. **Apple running, proxy holds 27015.** Launcher fell back to ephemeral IPC and
   respawns on a new port every 30–60 s. Noisy; the ephemeral tell is present.
2. **Apple not running at all, proxy holds 27015.** The app was closed (or its
   processes exited) and the portproxy reclaimed the port unopposed. Nothing to
   see on `127.0.0.1` because nothing is there to see.

Both need the same fix, and `fix-27015.ps1` handles both — in state 2 its
kill step is a no-op and it goes straight to relaunch. **State 2 is the better
one to run the fix from:** with no launcher alive there is no ephemeral respawn
churn racing the `netsh` delete, so the single elevated pass is uncontested.

Diagnosis rule: `0.0.0.0 <- svchost` present **and** no `127.0.0.1 <- Apple*` is
sufficient on its own. Absence of Apple processes corroborates it, it does not
contradict it.

### When the session cannot elevate

The elevated step is genuinely irreducible: freeing the port is
`netsh interface portproxy delete`, which returns `requires elevation`
unelevated, and there is no unelevated substitute — the wildcard `0.0.0.0` bind
is what blocks Apple's `127.0.0.1` bind, stopping `iphlpsvc` also needs admin,
the ephemeral port speaks the wrong protocol, and `usbipd` is forbidden for
separate reasons (below). An agent or session that cannot prompt for UAC should
**do every unelevated gate first** — mirror sync, build artifact, gateway,
pairing record — so that when the user does elevate, the fix plus a `-SkipSync`
re-run is all that remains, rather than discovering a second problem afterwards.

**Do not launch the Apple Devices app as a consolation move.** Added 2026-08-03.
It is unelevated, so it is available, and it looks like partial progress toward
the fix — it is the opposite. In state 2 (proxy alone, no Apple process) the
`netsh` delete is uncontested; launching the app first only moves the system
into state 1, where the launcher respawns on a new ephemeral port every 30-60 s
and actively races the fix. `fix-27015.ps1` relaunches the app itself, in the
right order, inside the elevated pass. Leave it closed and hand over.

### State 3: Apple holds 27015 but the portproxy is gone

Seen 2026-08-04, and it is the **inverse** of everything above — which makes the
section you just read actively misleading if you reach for it here. Symptoms:

```
netsh interface portproxy show all   -> empty table
127.0.0.1 <- AppleMobileDeviceProcess   (present)
0.0.0.0   <- svchost                    (ABSENT)
```

Preflight passes steps 0-2 and fails **step 3** with `No device`; from the
distro, `idevice_id -l` returns empty with exit 0 and `xtool devices` says
`Operation now in progress` — note that is *not* `Operation not permitted`,
which is the classic race. Apple's side is healthy and holding the port
correctly; there is simply nothing on `0.0.0.0`, so WSL's connection goes
nowhere.

How it happens: `fix-27015.ps1` ran and won the hard half (freeing the port so
Apple binds `127.0.0.1:27015`) but the proxy was not re-added, or was dropped
afterwards. The script's own step 1 names this case - *"Apple holds the port
but the portproxy is missing; WSL cannot reach it"* - but it is easy to see
"step 3 failed" and re-run the whole script.

**Do not re-run `fix-27015.ps1`.** Its first act is to kill Apple's processes,
which throws away the state you just won and makes you re-run the race for
nothing. The missing half is one elevated line:

```powershell
netsh interface portproxy add v4tov4 listenport=27015 listenaddress=0.0.0.0 `
  connectport=27015 connectaddress=127.0.0.1
```

**And then check the process list, not just the ports.** In this instance the
proxy came back and step 3 *still* failed, because only
`AppleMobileDeviceLauncher` and `AppleMobileDeviceProcess` were running -
`AppleDevices` and `AMPDevicesAgent` were not. The app itself is the usbmuxd
provider, so the bridge was intact and had nothing behind it.

Here - unlike the "consolation move" warning above - **launching the Apple
Devices app is exactly right**, because Apple already owns `127.0.0.1:27015`
and there is no race left to lose. The warning applies only while the *proxy*
holds the port. Launch it unelevated:

```powershell
explorer.exe 'shell:AppsFolder\AppleInc.AppleDevices_nzyj5cx40ttqa!App'
```

Roughly twelve seconds later the process list gained `AMPDevicesAgent`,
`AppleDevices` and `AppleMobileDeviceHelper`, `idevice_id -l` returned the
UDID, and the deploy ran clean. Healthy is **five** Apple processes, not two.

Diagnosis rule: both listeners present but no device means look at the process
list before touching the port again.

### Free-profile App ID cap is 3

```
ApplicationVerificationFailed: This device has reached the maximum number of
installed apps using a free developer profile: { com.example.Vinodex,
com.example.Hello, com.example.VinodexSpike }
```

The cap is on **App IDs registered to the profile, not apps installed on the
device.** `xtool uninstall` reports `Success!` and frees nothing — the App IDs
stay held.

This is why `ios/xtool.yml` used `com.example.Vinodex` until 2026-08-11:
reusing an existing App ID was the only way to deploy on the free profile.
The account is paid as of 2026-08-11 (no App ID quota), and `xtool.yml` now
carries the real `com.blaikooz.vinodex` — see the one-way-door section below
for what that change does to on-device data.

### Changing the bundle ID is a one-way door

*(AUDIT **M35**. Read this before touching `xtool.yml:8`.)*

**The ID is `com.blaikooz.vinodex`, set on 2026-08-11 on the paid account.**
History: introduced at `b59cafb` with the note that `com.example.Vinodex` is a
template value Apple rejects, reverted at `b732221` for the quota above,
restored when the account went paid. The door has been walked through — what
follows is the record of what that means for on-device data.

**On iOS the bundle ID *is* the container identity.** A new App ID gets a new
`Library/Preferences/<bundleID>.plist` and a new `Library/Application Support/`.
The old container is not readable from the new binary, not enumerable, and is
deleted with the old install. **All 20 keys in `SavedDataKey`
(`Sources/VinodexCore/SavedData.swift`) and the profile photo at
`Application Support/avatar.jpg` stay behind.** The audit item asked for "a
data-migration step"; no such step is writable, and code claiming to be one
would be a lie. What exists instead is BACK UP / RESTORE in
SETTINGS ▸ STORED DATA, which writes a `SavedDataArchive` the user keeps
outside the container.

Preconditions, and how each was met (or wasn't) when the ID changed on
2026-08-11:

1. **Quota freed, or a paid account.** Met — the account went paid 2026-08-11.
2. **App Group migration** (register `group.com.blaikooz.vinodex`, add it to
   the **old** App ID, move defaults to `UserDefaults(suiteName:)` *before*
   the change). **Not done, and not writable:** xtool 1.17 has no entitlements
   key in `xtool.yml`, so this needed a signing pipeline that did not exist.
   A group added *after* the change shares an empty container.
3. **A build containing BACK UP shipped first.** Met — BACK UP / RESTORE has
   been in SETTINGS ▸ STORED DATA since before the change.
4. Change `xtool.yml:8`. Done 2026-08-11.
5. The first build under the new ID should put RESTORE where it will be found.

**The residual, plainly:** step 2 being unavailable means the archive is the
whole of the answer. Before deleting the old `com.example.Vinodex` install,
take BACK UP inside it; RESTORE into the first `com.blaikooz.vinodex` build.
The old container is deleted with the old install, and nothing else carries
the 20 `SavedDataKey` keys or `avatar.jpg` across.
### Provisioning fails with a 409 `ENTITY_ERROR` about device IDs

Seen 2026-08-03. The deploy clears all three preflight gates, gets through
`Unpacking` and `Preparing device`, and dies in **Provisioning**:

```
Error: Unexpected response, expected status code: created, response: conflict(
  ... status: "409", code: "ENTITY_ERROR",
  detail: "There are no current IOS devices on this team matching the provided
  device IDs.")
```

**This is not the 27015 race** — the port was healthy and the device was visible.
It is Apple Developer Services being eventually consistent with itself, and it
resolves on its own. Diagnose it before touching anything:

```bash
wsl -d xtool-ubuntu -- bash -lc "xtool auth status"        # which Apple ID / team
wsl -d xtool-ubuntu -- bash -lc "xtool ds teams list"      # free vs paid, and how many
wsl -d xtool-ubuntu -- bash -lc "xtool ds devices list"    # is the UDID registered?
wsl -d xtool-ubuntu -- bash -lc "xtool ds profiles list"   # did a profile get made?
```

None of those need the phone, the port, or elevation — they are pure web API
calls, so **this whole diagnosis is available while the bridge is down.**

What the timestamps showed here: the device record was created at 13:26 and the
`com.example.Vinodex` profile at 14:01, both on the day of the failure. So
xtool *had* registered the device — the failing run registered it itself — and
then the profile-creation call in the same run raced ahead of the registration
propagating to the profile service. The device was `ENABLED` and the profile
`ACTIVE` by the time anyone looked.

**The rule: on a 409 here, re-run. Do not "fix" it.** Specifically do not change
the bundle ID (it is a one-way door for on-device data — see above; on the old
free account it also burned quota), do not `xtool auth logout`, and do not go to the Developer portal to add
the device by hand. Every one of those is a plausible-looking response to the
error text and all three make things worse. If `xtool ds devices list` shows the
UDID present and `ENABLED`, the account side is *already correct* and the only
missing ingredient is time.

Escalate to the user only if the device genuinely is **absent** from
`xtool ds devices list` after a re-run, since `xtool ds devices` has `list` as
its only subcommand — there is no CLI path to register one.

Two things that make this recur rather than being a one-off:

- **Free-provisioning device registrations lapse.** Profiles from 27-28 July
  referenced this same UDID, yet the device record was re-created on 3 August.
  The registration had expired and xtool silently re-made it — which is what
  opened the propagation window in the first place.
- **Free-team profiles expire after 7 days**, same clock as the signed build.
  `xtool ds profiles list` showing `profile state: INVALID` for old bundle IDs
  is normal and not worth chasing; only the row for the App ID in `xtool.yml`
  matters.

### `Multiple library products were found` at Planning — xtool.yml needs `product`

Seen 2026-08-10 deploying v0.9.0. `xtool dev build` exits 1 immediately after
`Planning...` with:

```
Error: Multiple library products were found (["Vinodex", "VinodexCore", "VinodexUI"]).
```

The v0.9.0 reorg (PR #13) deliberately exports `VinodexCore` and `VinodexUI` as
library products alongside `Vinodex` (arch A5 — so a future CLI validator or
macOS target can depend on them), and xtool 1.17.0 refuses to guess which of
the three is the app. The fix is one line in `xtool.yml`:

```yaml
product: Vinodex
```

`Vinodex` is the product wrapping the `VinodexApp` target — see the `products:`
block at the top of `Package.swift`. Do **not** "fix" it by deleting the extra
products from `Package.swift`; they are exported on purpose.

Two observations from the same session:

- The `Error:` line goes to stderr and is easy to lose — a transcript that just
  shows `Planning...` then exit 1 is this (or a sibling planning error). Re-run
  inside WSL with `2>&1` in the bash command to see the text.
- The first `xtool dev run` after the fix died silently right after
  `Build complete!` (again, stderr lost) and the immediate warm re-run went
  through Provisioning -> Install -> Verify cleanly — consistent with the
  transient 409 above. Re-run before diagnosing.

Timing note: at v0.9.0 size (~159 Swift files) a clean `xtool dev build` is
**~300s**, not the 210-230s measured earlier — budget ~5.5 min for clean
build + install before concluding anything is stuck.

### Pre-flight checklist

**There is a script for the whole thing now: `scripts/deploy-iphone.ps1`**
(added 0.7.1). Unelevated, from PowerShell:

```powershell
.\scripts\deploy-iphone.ps1              # preflight -> sync -> build -> install
.\scripts\deploy-iphone.ps1 -CheckOnly   # is the phone reachable? changes nothing
.\scripts\deploy-iphone.ps1 -Clean       # rm -rf .build first, after Swift changes
.\scripts\deploy-iphone.ps1 -SkipSync    # re-run after fixing the port mid-deploy
```

It gates in the order that matters — port, gateway, device, sync, build — so a
broken bridge costs seconds instead of a ten-minute build, and it passes
`USBMUXD_SOCKET_ADDRESS` inline with a `timeout` around the device probe so the
classic silent hang becomes a real failure. It never elevates: on an unhealthy
port it prints the `fix-27015.ps1` command and stops. Exit codes: `2` port,
`3` no route, `4` no device, `5` sync, else xtool's own.

The steps it automates, for when you are doing it by hand:

1. Phone plugged in, unlocked, trusted. Pairing record:
   `C:\ProgramData\Apple\Lockdown\<UDID>.plist`
2. `127.0.0.1:27015` held by `AppleMobileDeviceProcess` (see above)
3. rsync the WSL mirror — see [WSL mirror goes stale](#the-wsl-mirror-goes-stale)
4. `wsl -d xtool-ubuntu -- bash -lc "cd /root/projects/vinodex-ios && USBMUXD_SOCKET_ADDRESS=172.20.80.1:27015 xtool dev run"`

Signed with a free profile, so **builds expire after 7 days.**

> Both `scripts/*.ps1` here are **ASCII only** on purpose. Windows PowerShell
> 5.1 reads script files as ANSI, so a UTF-8 em-dash inside a string is a
> parser error — and the cascade it produces points at unrelated lines.

---

## Traps that produce false readings

These cost real debugging time because the tool lies rather than erroring.

**Unelevated firewall queries return false negatives.** `Get-NetFirewallRule` /
`Get-NetFirewallPortFilter` will report the `WSL usbmuxd 27015` rule missing when
it exists. Always check from an elevated shell before concluding anything about
the firewall.

**`bash -lc` through `wsl.exe` mangles quoting.** Constructs like
`$(ip route show default | cut -d" " -f3)` silently evaluate to empty — no error,
just an empty variable and a confusing downstream failure. Put the commands in a
`.sh` file and run it. A `grep -E "a|b|c"` inside the same quoting is mangled the
same way and comes back as `command not found`; redirect to a file and read it.

**`USBMUXD_SOCKET_ADDRESS` arrives empty under `wsl.exe -- bash -lc`.**
`/etc/profile.d/xtool-usbmuxd.sh` sets it from a command substitution, which is
exactly the construct above, so the variable ends up empty even though the file
is sourced. libimobiledevice then falls back to a local unix socket and `xtool`
**hangs** rather than erroring. Pass it explicitly:

```powershell
wsl.exe -d xtool-ubuntu -- bash -lc "cd /root/projects/vinodex-ios && USBMUXD_SOCKET_ADDRESS=172.20.80.1:27015 xtool dev run"
```

The gateway is whatever `ip -o route` reports for `default` (172.20.80.1 as of
2026-07-29; it changes).

**`/root/.bashrc` reads `$PS1` unguarded.** Any script that does `set -u` and
then sources `/root/.profile` aborts with `PS1: unbound variable` before running
a line of its own. Drop `set -u` in scripts that source the profile.

**`pkill -f xtool` kills the shell running it.** The pattern matches the
invoking `bash -lc` command line, which contains the word. The tool reports exit
15 and nothing else happens. Use a bracket trick (`xtoo[l]`) or match the binary.

**Invoke WSL from PowerShell, not Git Bash.** Git Bash rewrites `/mnt/c/...` into
`C:/Program Files/Git/mnt/c/...`, giving `No such file or directory`:

```powershell
wsl.exe -d xtool-ubuntu -- bash /mnt/c/Users/.../script.sh   # from PowerShell
```

**drvfs metadata is stale immediately after an rsync.** `ls` / `stat` in the same
script run can report old sizes and "missing" files that were definitely copied.
Re-check in a **separate** invocation before believing it.

**`which` in a non-login shell under-reports.** It missed an installed
`rsvg-convert`. Use `bash -lc` or check the package directly.

---

## Build & test gotchas

### `swift build` cannot see three-quarters of the app — run the typecheck script

`swift build` reports **"Build complete!"** with a type error sitting in
`VinodexUI`. UIKit does not exist on macOS or Linux, so every file guarded
`#if canImport(SwiftUI) && canImport(UIKit)` compiles to *nothing* and its
errors are never raised. `swift test` needs full Xcode; `xtool` has no `test`
subcommand. Nothing in this repo checks the UI layer before a push.

On a Mac, this does:

```bash
scripts/typecheck-ios-surface.sh
```

It copies the tree, rewrites the genuinely iOS-only constructs, and type-checks
the whole thing against the macOS SDK with `scripts/typecheck-shim.swift`
standing in for UIKit. It reproduces the actor-isolation errors CI reports, at
identical file:line:col.

Three things to know before trusting it:

- **Mac only.** It needs AppKit and SwiftUI, so on the WSL box CI is still the
  first real check.
- **A shim gap looks exactly like a bug.** If it names a UIKit member the shim
  lacks, add the stand-in to `typecheck-shim.swift` — do not "fix" the app.
- **`scripts/typecheck-baseline.txt` is not a wishlist.** swiftc skips function
  body type-checking in *every* file once one declaration-level error exists, so
  a script with a few tolerated errors is a script that silently checks nothing.
  Each baselined line carries its reason; keep it that way, and prefer fixing to
  adding.

CI's `iOS compile (Xcode)` job remains authoritative — but note it stops after
its first batch of files, so one error there hides every file alphabetically
after it. The script has no such limit, which is most of why it is worth having.

### The WSL mirror goes stale

Swift builds do **not** run against the checkout. `/root/projects/vinodex-ios`
inside `xtool-ubuntu` is a plain rsync mirror with no `.git` — building over the
`/mnt/c` 9p mount is drastically slower, which is why it exists. It goes stale
silently, so a green `swift test` can reflect old code. **Windows is the source
of truth — never edit the WSL copy.**

```bash
rsync -a --delete --exclude ".build/" --exclude "xtool/" --exclude ".git/" \
  /mnt/h/vscode-projects/HGapps/vinodex-ios/ \
  /root/projects/vinodex-ios/
```

Excluding `.build/` preserves the incremental cache; excluding `xtool/` preserves
the built `.app`; excluding `.git/` keeps the history off the copy.

**Path history — check this first if a build compiles something you did not
write.** The Windows source was `VINODEX/native/` before 2026-07-28,
`VINODEX/ios/` until 2026-07-29, and is now this repo's root: the Swift package
*is* the repo, so the whole tree syncs. The WSL target was `vinodex-native` over
that whole period and is now `vinodex-ios`.

### `swift test` cannot see any UI code

`VinodexCoreTests` depends on `VinodexCore` alone, and `VinodexUI` is wrapped in
`#if canImport(SwiftUI)` — on Linux it compiles to nothing. **A syntax error in
`VinodexUI` will not fail `swift test`.** Only `xtool dev build` compiles it.

Corollary: any `WineDatabase` helper defined in `VinodexUI` is invisible to its
own tests. Pure data queries belong in `VinodexCore/WineDatabase.swift`.

`VinodexUI` and `VinodexApp` have **zero** test coverage; UI work is verified
visually only.

### `.contentShape` outside `.offset` moves the hit region back

Cost three batches (0.7.0 → 0.7.2). Stamps on the back plate were completely
undraggable *and* untappable, and two attempts to fix it tuned the long-press
duration instead.

```swift
.frame(width: w, height: h)
.offset(x: at.x, y: at.y)
.contentShape(Rectangle())   // WRONG — hit region stays at the layout frame
.gesture(…)                  // never receives a touch
```

**`.offset` is a render-time translation; it does not change layout.** In a
`ZStack(alignment: .topLeading)` every child's layout frame is the same box in
the corner, and only the drawing moves. `.contentShape` applied *outside* the
offset therefore defines its rectangle in the un-offset space — and it does not
merely describe a hit region, it **replaces** the subtree's. Six stamps ended up
sharing one touch target stacked in the plate's top-left corner while every
stamp on screen was inert.

Put `.contentShape` immediately after `.frame`, inside the offset, so the offset
carries the hit region along with the pixels.

**The diagnostic lesson is the more general one: a threshold change that alters
nothing is evidence the event never arrived.** 0.7.1 shortened the hold from
0.35s to 0.25s and reported no improvement, which should have been read as "no
touch is reaching this recogniser" rather than "0.25 is still too long". A dead
gesture and a mistuned one look identical from the outside; the cheap
discriminator is to check whether a *different* gesture on the same view still
works. Taps on those stamps had been dead the whole time and nobody had tried.

Second, latent trap in the same chain: **`.gesture(_:)` attaches with *lower*
precedence than gestures already declared on the view.** A `.gesture(longPress
→ drag)` sitting below an `.onTapGesture` is the losing side of an exclusive
pair, and SwiftUI's `TapGesture` has no maximum duration, so a deliberate
press-and-hold-and-release reads as a tap. Use `.highPriorityGesture` when a
hold must get first refusal, or `.simultaneousGesture` when both should survive
(`MarqueeDrawer`'s hold-to-pin).

### A renamed repo poisons the Actions `.build` cache

Symptom, on every file in the module, for a branch that tests green locally:

```
error: PCH was compiled with module cache path
  '/__w/vinodex-swift/vinodex-swift/.build/.../ModuleCache/1I141E7TZTTFA',
  but the path is currently
  '/__w/vinodex-ios/vinodex-ios/.build/.../ModuleCache/1I141E7TZTTFA'
error: missing required module 'SwiftShims'
```

`.build` holds precompiled headers with **absolute** paths baked in. This repo was
renamed `vinodex-swift` → `vinodex-ios`; the cache key was keyed only on
`hashFiles('Package.swift', 'Package.resolved')`, which had not changed, so the
run happily restored a `.build` built under the old checkout path and every
compile failed.

Nothing in the error mentions the cache or the rename, and `swift test` passes
locally, so it reads as a corrupt toolchain. **The repository name is now part of
the cache key** (and of `restore-keys`, or the prefix fallback walks right back
into the stale entry).

If it happens again — any change to the checkout path will do it — clear the
cache and re-run:

```powershell
gh cache list
gh cache delete <id>        # or: gh cache delete --all
```

### `rethrows` methods cannot sit inside `#expect`

`allSatisfy`, `contains(where:)`, `map`, `first(where:)` — anything `rethrows` —
fail to compile inside a swift-testing `#expect`, even with a non-throwing
closure or key path:

```
error: call can throw, but it is not marked with 'try' and the error is not handled
macro expansion #expect:2:3
```

The macro expands the expression into a form the compiler analyses as throwing.
The error points at the *expansion*, not at your line, so it reads as a compiler
bug. Hoist the call into a `let` and `#expect` the result:

```swift
let allNumeric = part.allSatisfy(\.isNumber)   // not inside #expect
#expect(allNumeric, "…")
```

### xtool stamps a fake version into every bundle

xtool 1.17 writes `CFBundleShortVersionString = 1.0.0` and `CFBundleVersion = 1`
into the built `.app` unconditionally. So anything reading the bundle for a
version gets `1.0.0` unless the build says otherwise.

`AppVersion` therefore keeps a `placeholders` denylist and prefers its own
constant over those values — without it the back plate reported `v1.0.0` on
every build ever made, which it silently did until 2026-07-29. **The day this app
genuinely ships 1.0.0, that denylist has to change or the release under-reports
itself.** `AppVersionTests` pins the behaviour.

> **Corrected 0.7.2.** This section used to assert that "there is no `xtool.yml`
> key to override either". That is false of the installed xtool 1.17.0, whose
> schema is `version, orgID, bundleID, product, infoPath, entitlementsPath,
> iconPath, resources, extensions[]`. **`infoPath:` is a real Info.plist
> passthrough**: xtool builds its default dictionary, then shallow-merges the
> referenced file's top-level keys over it with the file winning. Only four keys
> are stamped *after* the merge and are therefore genuinely unsettable —
> `UIRequiredDeviceCapabilities`, `LSRequiresIPhoneOS`,
> `CFBundleSupportedPlatforms` and `CFBundleIconFile`. `CFBundleShortVersionString`
> is **not** among them.
>
> The repo now has an `Info.plist` (added for LABEL SCAN's camera and photo
> usage strings, 0.7.2, LR1) wired up through `infoPath:`. The denylist above
> stays regardless: it is the belt against a build that declares nothing, and
> stamping the version from two places — this constant and a plist — would be
> two things to keep in agreement. Verify a merge landed with
> `plutil -p /root/projects/vinodex-ios/xtool/Vinodex.app/Info.plist` in WSL.

This is also why releases are marked with **annotated git tags** (`v` +
`AppVersion.fallback`) rather than by a bundle version: git is the only place the
real number can live until there is a signing pipeline that sets its own.

The annotations are the release notes, and [`CHANGELOG.md`](CHANGELOG.md) is the
browsable half of the same record (AUDIT **M37**). Twenty-two of the 28 tags were
**backfilled on 2026-08-03** with `GIT_COMMITTER_DATE` set to each commit's own
date, so `git tag --sort=taggerdate` reports release order rather than backfill
order — every backfilled annotation says so in its last paragraph. Four numbers
have CHANGELOG entries and no tag on purpose (`0.5.8`–`0.6.1`): they were real
batches that landed inside one commit, so there is no tree to point a tag at, and
the table at the foot of CHANGELOG.md records why.

### Long jobs need an attached session

WSL2 tears down the VM shortly after the last shell detaches — `nohup` and
`systemd-run` are both insufficient. Symptoms are misleading (truncated
`gzip: unexpected end of file`, `tar: Cannot utime`) and look like corrupt
downloads. Run long jobs inline in an attached session.

### Regenerating data

```bash
npm install
npm run generate          # rewrites the six JSON files under Sources/
npm run icons             # needs rsvg-convert + Pillow + network
```

Generation is **deterministic** — a change scoped to the icon tables leaves
`entries.json` and `palette.json` byte-identical. Always `git diff --stat` the
`Sources/VinodexCore/Resources/` directory afterwards; an unexpectedly large diff
means the change was wider than intended. CI checks this too: the `generated data
is current` job fails a push whose `shared/` and committed JSON disagree.

Both scripts read `shared/`, a sibling of `scripts/` in this repo. Until
2026-07-29 they probed for `ios/Package.swift` so one copy could serve both this
repo and the monorepo it was published from; there is one layout now and the
paths are direct.

### Iconify ids must be verified before use

`rasterize-icons.sh` reports `FAIL not svg` on a miss, because the API answers a
missing icon with a text body rather than an error status. Check first:

```bash
curl -s "https://api.iconify.design/<prefix>/<name>.svg" | head -c 60
```

Several plausible names do not exist — `game-icons:europe`, `game-icons:asia`,
`game-icons:north-america`, `game-icons:raw-ore`.

### SF Symbols have OS floors the compiler will not check

The deployment target is iOS 17, so an iOS 18+ symbol (anything
`*.trianglehead.*`) compiles cleanly and renders **blank on device**. The same
applies to SwiftUI API: `onGeometryChange(for:)` is iOS 18 and silently does
nothing on 17 — use a `GeometryReader`.

---

## Open bugs

**Bundle ID migration is user-dependent.** The ID became the real
`com.blaikooz.vinodex` on 2026-08-11 (paid account); data on the old
`com.example.Vinodex` install only crosses over via BACK UP / RESTORE — see
"Changing the bundle ID is a one-way door" above.

**`VinodexUI` and `VinodexApp` have no test coverage.** The test target depends
on `VinodexCore` only, so every UI change is verified by eye on the device.

### Fixed, kept as precedent

**The macOS build break** (fixed 2026-07-28). `MainMenuScreen` was guarded
`#if canImport(SwiftUI)` but called `Haptics`, guarded `#if canImport(UIKit)`,
so a macOS build compiled the caller without the callee. Eight files had the
same latent mismatch. All of `VinodexUI` that touches `Haptics`, `DexIcon`,
`DexSearchField` or `SettingsPanel` is now guarded
`#if canImport(SwiftUI) && canImport(UIKit)`.

*Precedent:* `swift build --swift-sdk darwin` targets **macOS**, while
`xtool dev build` targets iOS — so the two catch different errors. A green
`xtool dev build` does not mean the package builds for macOS.

**Soil keyword list was duplicated** (fixed 2026-07-28). Match keywords lived in
`WineDatabase.soilIcon(_:)` while the table lived in `SOIL_ICONS`; they drifted
and six soils silently fell back to the default glyph. The generator now emits
`soilKeywords` into `icons.json` and Swift iterates that. Order is significant —
first substring wins, so `clay` must precede `loam`.

---

## Repo layout

This repo **is** the Swift package — `Package.swift` sits at the root, not under
a subdirectory. It owns everything it needs:

| Path | What it is |
|---|---|
| `Sources/`, `Tests/`, `Package.swift`, `xtool.yml` | the app |
| `shared/` | data + colour tables, pure TS, zero dependencies |
| `shared/pixelflags/` | pixel-art flags — the one art asset both repos consume, so it lives in the cross-repo master (`HGapps\shared`, mirrored by `sync-shared.ps1`) rather than in `art/`. Source for `Sources/VinodexUI/Resources/Flags`. The pack is R74n's: credited in NOTICE.md, non-commercial without permission (auditS H2) — fine for dev builds; permission has been requested from R74n, and a first-party standby set sits at `art/flags/` for the paid release |
| `art/` | drawn icon source art + audio masters + the standby code-drawn flag set (`art/flags/`, from `scripts/generate-flag-art.py`), one folder per use |
| `scripts/` | `generate-ios-data.ts`, `rasterize-icons.sh`, `generate-flag-art.py`, the five art importers, `verify-art.py` |

One remote, `origin` → `blaikooz/vinodex-ios`. Commit and open PRs here.

**Keep `shared/` dependency-free.** The generator runs it under bare `node`
(v22.18+ strips TypeScript types natively; `npm run generate:tsnode` is the
ts-node fallback for older Node — arch B4) where nothing else is installed; a
single `react` import there breaks data regeneration.

### It used to be a generated mirror

Until 2026-07-29 this repo was assembled from `blaikooz/vinodex` (the web
monorepo) by `scripts/publish-swift.mjs`. That script **emptied the tree and
rebuilt it** on every publish, so anything living only here was deleted — which
is how the merged PR #1 lost `AUDIT.md` on 2026-07-29 before it was restored.

That path is gone: the script, the `swift` remote, the `swift-main` branch and
the npm entry points were all deleted from the monorepo in the same change. The
monorepo still contains frozen copies of `ios/`, `shared/`, `pixelflags/` and
the two scripts — **nobody edits those**; they are leftovers the web pivot will
remove on its own schedule. Nothing copies between the two repos in either
direction any more.

If you ever find a script anywhere that writes into this repo from outside it,
that is a bug — delete it.
