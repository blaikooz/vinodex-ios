# vinodex 0.8.3 — spec

*Draft for `dexbot`. Eight items. **D is the only one with a data-loss shape** —
read its note before touching anything. Everything else is chrome and layout.*

Cut `v0.8.3-batch` from the 0.8.2 tip (`2c01272`). 0.8.2 is deployed and tested
on device, so this branches from a known-good build.

`shared/` is free this batch — no sommbot pass is running.

---

## A. Marquee page glyphs use the new icon set, all black

The marquee's page glyphs become the 0.8.1 button art (`DexChromeGlyph` /
ButtonArt), rendered **entirely black** rather than skin-tinted or inked.

Note this is the opposite treatment from 0.8.2's footer caps, which take the
skin's hue and saturation through `ChassisCapLoader`. Do not route these through
that loader — flat black is the ask, and the marquee ground is its own surface.
If the marquee already has an ink rule that black fights on some skins, say so
rather than silently exempting one.

---

## B. Footer buttons: no shadow, and they depress

0.8.2 replaced the four footer caps with whole moulded sprites (rim, cast shadow,
incised symbol) via `ChassisCapArt.swift`.

- **B1.** Remove the shadow from the new caps.
- **B2.** They **depress** on press.

The orb already has the depress vocabulary — `DeviceChassis.swift` drives
`orbHeld` with a scale and brightness change on `onPressingChanged`. Reuse that
feel rather than inventing a second one; the two sit on the same chassis.

If the shadow is baked into the PNGs rather than drawn in SwiftUI, that is an
art re-export through `import-button-art.py`, not a code change — say which it
turned out to be.

---

## C. Cartridge pages: the cartridge becomes the page

- **C1.** Remove the folder icon sitting behind the pack.
- **C2.** Centre the cartridge icon.
- **C3.** Make it **much** larger.
- **C4.** Move the pack text **inside** the cartridge art, into the empty space
  at the bottom.

C4 is the constraint that drives the rest: the cartridge sprites have a label
well at the bottom, and the text belongs in it. Check the text fits at the
longest pack name before settling the size — and note 0.8.2 flagged that
`chassisskins`, `screenmodes` and `vinodexpro` are roughly **2× the linear size**
of the other fourteen, so the label well is not in the same relative place on all
seventeen. That is the thing most likely to make C4 look right on fourteen and
wrong on three.

---

## D. Remove four packs — READ THIS FIRST

Remove **flavorwheel**, **Italy pack**, **France pack** and **Spain pack**.

**These are purchasable entitlements with persisted ids.** `Entitlements.swift:18`
carries `case country(String)`, serialised at line 56 as `"country:" + name` — so
`country:France` is a string on somebody's disk. The same is true of flavorwheel
under its own id.

Two things must be true when you are done, and neither is automatic:

1. **The content does not disappear.** Removing a pack removes a *paywall*, not
   entries. Every grape and region those three country packs gated must remain
   reachable — free, not orphaned. Deleting the pack and leaving its entries
   gated by an id nothing sells would make that content permanently unreachable,
   which is the failure mode to design against.
2. **Existing owners do not hit a crash or a phantom.** A persisted
   `country:France` must decode without trapping and without displaying a pack
   that no longer exists. Check the decode path, the restore path, and anything
   that iterates owned entitlements to build a list.

Also check: `ExpansionPacks.all.count` is pinned (it was 12), `FREE_COMMON_ORIGINS`
interacts with country gating, and the passport/stamp surfaces may count packs.
0.7.9's F is the precedent for how pack membership arithmetic gets pinned.

**If you find that removing these cannot be done without orphaning content or
breaking a persisted id, stop and report rather than shipping half of it.**

---

## E. Shop: no file icon behind packs, slightly larger icons

- **E1.** Remove the file/folder icon behind each pack on the shop shelf.
- **E2.** Make the pack icons **a bit** larger — a step, not the C3 treatment.

C and E are the same removal on two surfaces (the shelf and the pack page). If
the backing icon is one component, delete it once.

---

## F. Display packs show the full mockup with icons

0.8.2 gave display packs a `ScreenMockup` preview. It should show the **full**
mockup **with icons**, exactly as it appears in Customise — not a reduced
version.

`ScreenMockup.swift` is new as of 0.8.2 and was untested by anything but the
compiler, so expect to be finishing it rather than adjusting it. The Customise
screen is the reference; match it rather than approximating.

---

## G. Style scan: origin moves to a horizontal bar

In the style entry screen, the origin attribute moves out of the tile row and
onto its own horizontal bar below — exactly as grape entries got in 0.8.0's G2.

0.8.0 extracted `keyGrapeBar` into `attributeBar` for that item, with ORIGIN as
a second caller. This is a third caller, not a new component. If it does not
factor, say so rather than copying it.

---

## H. Marquee status lights use the new glyphs, coloured in

The marquee's status-light glyphs become the new icon set, **coloured in** —
unlike item A's flat black.

Note A and H are on the same surface with deliberately opposite treatments:
page glyphs flat black, status lights coloured. Make sure whatever mechanism you
use can express both without one leaking into the other, and confirm the status
lights still read against every marquee ground.

---

## Order

**D first** — it is the only item that can fail outright, and finding that out
before eight other things are layered on top is worth more than the convenience
of doing the easy ones first. Then **C, E, F** (the shop/cartridge cluster, one
removal across two surfaces), then **A, H** (the marquee pair), then **B, G**.

## After the gates

This is the last batch of the night and the whole stack ships to `testing`. Run
the full gates, commit, and **stop** — do not push. The push is handed back.
