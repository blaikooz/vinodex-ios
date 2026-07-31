# Known issues & environment runbook

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

### Free-profile App ID cap is 3

```
ApplicationVerificationFailed: This device has reached the maximum number of
installed apps using a free developer profile: { com.example.Vinodex,
com.example.Hello, com.example.VinodexSpike }
```

The cap is on **App IDs registered to the profile, not apps installed on the
device.** `xtool uninstall` reports `Success!` and frees nothing — the App IDs
stay held.

This is why `ios/xtool.yml` still uses `com.example.Vinodex`: reusing an
existing App ID is the only way to deploy. Changing it to a real reverse-DNS ID
needs the quota to free up or a paid account.

### Pre-flight checklist

1. Phone plugged in, unlocked, trusted. Pairing record:
   `C:\ProgramData\Apple\Lockdown\<UDID>.plist`
2. `127.0.0.1:27015` held by `AppleMobileDeviceProcess` (see above)
3. rsync the WSL mirror — see [WSL mirror goes stale](#the-wsl-mirror-goes-stale)
4. `wsl -d xtool-ubuntu -- bash -lc "cd /root/projects/vinodex-native && xtool dev run"`

Signed with a free profile, so **builds expire after 7 days.**

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
into the built `.app` unconditionally, and **there is no `xtool.yml` key to
override either** (`version:` in that file is the config-schema version, not the
app's). So anything reading the bundle for a version gets `1.0.0`.

`AppVersion` therefore keeps a `placeholders` denylist and prefers its own
constant over those values — without it the back plate reported `v1.0.0` on
every build ever made, which it silently did until 2026-07-29. **The day this app
genuinely ships 1.0.0, that denylist has to change or the release under-reports
itself.** `AppVersionTests` pins the behaviour.

This is also why releases are marked with **annotated git tags** (`v` +
`AppVersion.fallback`) rather than by a bundle version: git is the only place the
real number can live until there is a signing pipeline that sets its own.

### Long jobs need an attached session

WSL2 tears down the VM shortly after the last shell detaches — `nohup` and
`systemd-run` are both insufficient. Symptoms are misleading (truncated
`gzip: unexpected end of file`, `tar: Cannot utime`) and look like corrupt
downloads. Run long jobs inline in an attached session.

### Regenerating data

```bash
npm install
npm run generate          # rewrites the five JSON files under Sources/
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

**Bundle ID is a placeholder.** `com.example.Vinodex` — see the App ID cap above.

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
| `shared/newicons/pixelflags/` | pixel-art flags (moved into the shared assets tree, 0.6.5), source for `Sources/VinodexUI/Resources/Flags` |
| `art/` | drawn icon source art + audio masters, one folder per use |
| `scripts/` | `generate-ios-data.ts`, `rasterize-icons.sh`, the four art importers, `verify-art.py` |

One remote, `origin` → `blaikooz/vinodex-ios`. Commit and open PRs here.

**Keep `shared/` dependency-free.** The generator runs it under plain `ts-node`
where nothing else is installed; a single `react` import there breaks data
regeneration.

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
