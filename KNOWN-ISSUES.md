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

### The 27015 port race — recurs on every reboot

**The single most likely reason a deploy fails.**

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
`.sh` file and run it.

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

Swift builds do **not** run against the repo. `/root/projects/vinodex-native`
inside `xtool-ubuntu` is a plain rsync mirror with no `.git`. It goes stale
silently, so a green `swift test` can reflect old code. **Windows is the source
of truth — never edit the WSL copy.**

```bash
rsync -a --delete --exclude ".build/" --exclude "xtool/" \
  /mnt/c/Users/StreetPC/Desktop/xtool/VINODEX/ios/ \
  /root/projects/vinodex-native/
```

Excluding `.build/` preserves the incremental cache; excluding `xtool/` preserves
the built `.app`.

The source path is `ios/` as of 2026-07-28 — it was `native/`. The mirror only
needs the Swift package, so `shared/` and `scripts/` are deliberately not synced;
regenerating data happens on the Windows side.

### `swift test` cannot see any UI code

`VinodexCoreTests` depends on `VinodexCore` alone, and `VinodexUI` is wrapped in
`#if canImport(SwiftUI)` — on Linux it compiles to nothing. **A syntax error in
`VinodexUI` will not fail `swift test`.** Only `xtool dev build` compiles it.

Corollary: any `WineDatabase` helper defined in `VinodexUI` is invisible to its
own tests. Pure data queries belong in `VinodexCore/WineDatabase.swift`.

`VinodexUI` and `VinodexApp` have **zero** test coverage; UI work is verified
visually only.

### Long jobs need an attached session

WSL2 tears down the VM shortly after the last shell detaches — `nohup` and
`systemd-run` are both insufficient. Symptoms are misleading (truncated
`gzip: unexpected end of file`, `tar: Cannot utime`) and look like corrupt
downloads. Run long jobs inline in an attached session.

### Regenerating data

```bash
npm run generate:ios      # from the monorepo root
npm run icons:ios         # needs rsvg-convert + network
```

Generation is **deterministic** — a change scoped to the icon tables leaves
`entries.json` and `palette.json` byte-identical. Always `git diff --stat` the
`ios/Sources/VinodexCore/Resources/` directory afterwards; an unexpectedly large
diff means the change was wider than intended.

Both scripts read from `shared/`, a sibling of `scripts/` in the monorepo **and**
in the published mirror, so the same two commands work in a `vinodex-swift`
checkout (as `npm run generate` / `npm run icons`). Before 2026-07-28 the
generator reached into the web tree and could only run here.

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

The repo root is `VINODEX/`, **not** the `xtool/` folder above it. `xtool/` is
the iOS *toolchain* container — it holds `downloads/` (the Xcode xip) and the WSL
`ext4.vhdx` — and happens to be where this repo was cloned. Running git from
`xtool/` gives *not a git repository*. The nesting is historical and slightly
misleading; nothing depends on it except the rsync path below.

It is a **monorepo with three peers** (restructured 2026-07-28, was web-at-root
plus `native/`):

| Path | What it is | Ships to `vinodex-swift`? |
|---|---|---|
| `shared/` | Data + colour tables, pure TS, zero deps | **Yes** |
| `web/` | Vite/React PWA | No |
| `ios/` | SwiftUI package | **Yes**, hoisted to the mirror root |
| `pixelflags/` | Pixel-art flags, source for both apps | **Yes** |
| `scripts/` | Generators, icon rasteriser, publish script | Two files only |

`shared/` is the single source of truth for grapes, regions, styles, countries
and every colour lookup. The web app reads it directly via the `@/shared/*`
alias; the iOS app reads the JSON that `scripts/generate-ios-data.ts` renders
from it. **There is no second copy of the data** — that was the point of the
restructure.

Two remotes:

| Remote | Repo | Contents |
|---|---|---|
| `origin` | `blaikooz/vinodex` | full monorepo |
| `swift` | `blaikooz/vinodex-swift` | assembled iOS mirror |

### Publishing `vinodex-swift`

```bash
npm run publish:swift:check     # assemble + verify, no commit
npm run publish:swift           # assemble + commit on swift-main
node scripts/publish-swift.mjs --push
```

This **replaced `git subtree split --prefix=native`** on 2026-07-28. A subtree
split takes only one prefix, so the published repo got the Swift package and
nothing else: `generate.ts` shipped importing `../../constants.ts` from a web
tree that wasn't there, and `rasterize-icons.sh` looked for a `pixelflags/` that
wasn't either. Both were dead files in `vinodex-swift`.

The mirror needs three prefixes, so it is assembled in a git worktree on
`swift-main` instead. `shared/`, `scripts/` and `pixelflags/` keep their
root-relative paths in the mirror, which is why `../shared/...` resolves
identically in both repos and the generator needs no path rewriting. Only the
Swift package moves — from `ios/` to the mirror root — and both scripts probe for
`ios/Package.swift` to find it.

The publish script **refuses to run with uncommitted changes** in any mirrored
path, since it builds from the working tree rather than from HEAD. It also
verifies that every relative import in the generator resolves inside the
assembled mirror — the check that would have caught the original breakage.

Commit to `master` as usual; publishing is a separate step and `swift-main` is
not a working branch. Never commit directly in `vinodex-swift`; it gets
overwritten.

Note `web/data/encyclopedia/source/sothebys-wine-encyclopedia-2005.raw.txt`
(4.5 MB of a copyrighted book) is committed and public in `blaikooz/vinodex`. It
is not among the mirrored paths, so it stays out of `vinodex-swift`.
