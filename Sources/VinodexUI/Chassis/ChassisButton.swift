#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// The chassis's moulded caps and the screen press, split out of
// DeviceChassis.swift (AUDIT **M30**) — that file had eleven top-level types in
// 1,220 lines. Nothing changed in the move itself; what has changed since is
// upstream's own work on these two types, carried across here rather than left
// behind in the monolith.
//
// `ChassisPress` / `ChassisPressStyle` — the *chassis* press these caps now use
// — stay in DeviceChassis.swift beside the orb that shares their numbers.

// MARK: - Chassis buttons

/// The physical-looking User, Home and Back buttons.
///
/// Haptics fire here rather than at call sites so every chassis button feels the
/// same — the main thing a native build can offer that the web app cannot.
struct ChassisButton: View {
    /// `bookmarks` is the band's User button (0.6.5, A1). It used to take
    /// Back's slot on the main screen, where there was nowhere to go back to;
    /// the band gives it a slot of its own, so the two no longer trade places.
    enum Kind { case back, home, bookmarks }

    let kind: Kind
    /// Diameter, passed rather than read from `DexMetrics`: the band sizes its
    /// controls itself (0.6.5), and the glyphs scale off whatever it asks for.
    let size: CGFloat
    let enabled: Bool
    let action: () -> Void

    /// Read here rather than passed down, the same way `DexToggle` reads the
    /// screen mode: the footer builds these, and threading it through would
    /// mean every future caller had to remember to.
    ///
    /// The *skin*, deliberately (v0.5.4, reversing 0.5.3): these are physical
    /// parts of the chassis, and physical parts belong to the colourway. A
    /// screen mode re-dressing the moulded buttons made every skin look like
    /// the same device the moment the LCD changed. On-LCD chrome (the search
    /// button, the settings tiles) still follows the mode — pixels on the
    /// screen are the screen's business.
    ///
    /// The eight stored settings, as one model (arch **A17**): the shell comes
    /// from `settings.chassisSkin` rather than from a thirty-sixth `@AppStorage`
    /// declaration of the same key with its own literal default.
    var settings: AppSettings = .shared

    /// The button axis (0.7.3, B1) — the one part override this view can see.
    /// Read here for the same reason the shell is: the footer builds these, and
    /// threading it through would mean every future caller had to remember to.
    ///
    /// Still an `@AppStorage`, and not a ninth property on `AppSettings`: the
    /// workshop's eight `DeviceAxis` keys are a separate system from the eight
    /// settings A17 models, and `MarqueeLampChooser` reads its own axis exactly
    /// this way.
    @AppStorage(DeviceAxis.buttons.storageKey) private var partButtons = ""

    /// The shell *as worn* — the skin, with whatever the workshop has overridden
    /// on the button axis laid over it (0.7.3, B1). Every `skin.control` and
    /// `skin.accent` below goes through the fallback rather than around it.
    private var skin: ChassisLook {
        ChassisLook(skinRaw: settings.chassisSkin.rawValue, buttons: partButtons)
    }

    init(
        kind: Kind,
        size: CGFloat = DexMetrics.bandControl,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.kind = kind
        self.size = size
        self.enabled = enabled
        self.action = action
    }

    /// The drawn cap's stem under `Resources/FooterArt`, less the prefix.
    ///
    /// `bookmarks` is `user`, which is the illustrator's word for it and the
    /// one on the file. The enum case is not renamed: it is matched on in five
    /// places and reads correctly beside `onBookmarks`.
    private var capStem: String {
        switch kind {
        case .back: "back"
        case .home: "home"
        case .bookmarks: "user"
        }
    }

    /// The face colour the drawn cap is re-inked to.
    ///
    /// Home's comes from its accent ramp rather than from `cap`, exactly as its
    /// gradient does — `cap` is documented as never read for Home, and reading
    /// it here would have made the one lit button in the band the one button
    /// that ignored its livery.
    private var capInkHex: String {
        switch kind {
        case .back, .bookmarks: cap.topHex
        case .home: homeAccent.lightHex
        }
    }

    /// The colour the incised symbol is re-inked to (0.8.4, E1).
    ///
    /// Resolved from the same two places as `capInkHex`, so a cap cannot take
    /// its face from one livery and its glyph from another. `ChassisControl.glyph`
    /// is the colour the no-art fallback has always tinted its SF Symbol with,
    /// which is what makes this a *correction* rather than a new decision: every
    /// skin had already chosen this colour, and the drawn caps were the only
    /// surface ignoring it.
    ///
    /// Home reads `ink` rather than `glyph` because Home has no `ChassisControl`
    /// -- `cap` is documented as never read for it -- and `ChassisAccent.ink` is
    /// that ramp's own answer to the same question, the one `moldedCap` already
    /// gives the house glyph on its fallback path.
    private var capGlyphHex: String {
        switch kind {
        case .back, .bookmarks: cap.glyphHex
        case .home: homeAccent.inkHex
        }
    }

    /// The drawn cap, re-inked, when there is one and the shell wants it.
    ///
    /// **Every shell takes them, as of 0.8.5 (D1).** FIBERGLASS was the last
    /// holdout, and the argument that kept it out is restated here rather than
    /// deleted, because it was a real one: that shell is a pen drawing,
    /// `SketchStroke` inks every circle by hand, and 0.6.6's B3 removed the cast
    /// shadow from it because "a cast shadow is the one thing a pen cannot do";
    /// a rendered pixel cap with its own baked highlight is a larger version of
    /// the same contradiction.
    ///
    /// Two things retire it. The first is that the contradiction has been
    /// shrinking on its own: 0.8.3's B1 removed the caps' painted cast shadow at
    /// import, and 0.8.5's E2 clips and feathers them to a fitted circle, so
    /// what a skin now adopts is a drawn *cap*, not a rendered photograph of
    /// one. The second is the item, which is worth taking at face value — the
    /// device's four most-used controls were one release behind on the shell a
    /// user has to pay to reach, and "it is consistent with the pen" is a
    /// smaller consideration than "it is the only skin still on the old
    /// buttons", which is what D1 says out loud.
    ///
    /// FIBERGLASS keeps its pen everywhere else: the body grain, the panel
    /// edges, the orb and the cog's rim are untouched, and the re-ink takes its
    /// own `#FBF8F1` face over `#2B3244` ink, which is the flattest pair in the
    /// range and the closest any skin gets to paper and pencil.
    private var drawnCap: UIImage? {
        ChassisCapLoader.shared.image(
            stem: capStem,
            inkHex: capInkHex,
            glyphHex: capGlyphHex
        )
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            // **The sprite replaces the control, not the glyph in it** (0.8.2).
            //
            // 0.8.1's J converted 32 button *faces*: glyphs that sit inside a
            // circle this view draws. These four are whole moulded caps — rim,
            // lit face, cast shadow, and the symbol incised into them. Drawing
            // one inside the gradient circle below would have stacked a painted
            // button on a rendered one, at two different rim radii.
            //
            // So the fallback is not a symbol here, it is *the entire existing
            // control*: no art, and every skin renders exactly what it rendered
            // in 0.8.1, down to the sketch stroke and the shadow. That keeps
            // "the conversion can be partial without any control being blank",
            // which is `DexChromeGlyph`'s rule and the only defence against
            // `PixelArtLoader` returning nil in silence.
            if let drawnCap {
                Image(uiImage: drawnCap)
                    // **Smooth, since 0.8.5 (E2)** — the same exception, for the
                    // same reason, that `DexChromeGlyph.smoothing` carved out
                    // for the marquee glyphs one release ago. The house rule is
                    // `.interpolation(.none)` because these are pixel art whose
                    // grid the illustrator drew; these four are not on a grid.
                    // They are a rendered circle at ~250px shown at 60pt, a 0.72
                    // downscale, and nearest-neighbour at 0.72 drops one row and
                    // column in four — which on a hard-edged disc with a dark
                    // cel outline running round it is precisely the stair-
                    // stepped fringe E2 reports. `ChassisCapLoader` feathers the
                    // silhouette so there is now something for the filter to
                    // resample.
                    .interpolation(.high)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    // No `.shadow`, for a different reason since 0.8.3 (B1).
                    // It used to be "the sprite casts its own, and the pair
                    // read as two light sources". B1 removes the sprite's, and
                    // it was removed *in the art* — the shadow was painted into
                    // the source as the magenta key at half value, so no
                    // SwiftUI change could have touched it. See
                    // `import-footer-art.py`'s `strip_key_shadow`. Adding a
                    // drawn shadow back here would be re-answering the item.
            } else {
                moldedCap
            }
        }
        // **The chassis press, not the screen press (0.8.3, B2).** These four
        // are moulded parts of the shell and now depress like the orb they sit
        // under — see `ChassisPress`, which holds the numbers both read.
        .buttonStyle(ChassisPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The rendered control, and the fallback for every cap with no art.
    private var moldedCap: some View {
        Group {
            ZStack {
                Circle().fill(gradient)
                // Hidden rather than skipped on the drawn skin (0.6.9, M1), so
                // the cap is the same stack of layers on every shell; the hand
                // line below replaces it. Same treatment as the cog's rim.
                Circle().strokeBorder(borderColor.opacity(skin.sketch == nil ? 1 : 0), lineWidth: 3)
                if let sketch = skin.sketch {
                    SketchStroke(
                        shape: { SketchCircle(seed: $0) },
                        ink: sketch.ink,
                        lineWidth: 2.2,
                        // Per-kind, so Back, Home and User are three different
                        // circles rather than the same wonky one stamped out
                        // three times — which is the tell that would give away
                        // that nobody drew them.
                        seed: sketchSeed
                    )
                }
                icon
            }
            .frame(width: size, height: size)
            // Softened in 0.6.6 (B3) — see `DexMetrics.bandShadowOpacity`. The
            // old 0.6/6/8 cast a near-black plate roughly a quarter of a
            // diameter below each circle, which is a sticker's shadow, not a
            // moulded cap's. Dropped entirely on the drawn skin: a cast shadow
            // is the one thing a pen cannot do.
            .shadow(
                color: .black.opacity(skin.sketch == nil ? DexMetrics.bandShadowOpacity : 0),
                radius: DexMetrics.bandShadowRadius,
                y: DexMetrics.bandShadowY
            )
        }
    }

    /// One wobble per kind — see the note at the call site (0.6.9, M1).
    private var sketchSeed: UInt64 {
        switch kind {
        case .back: 7
        case .home: 19
        case .bookmarks: 29
        }
    }

    /// VoiceOver reads the SF Symbol otherwise — Saved announces as "person",
    /// and Back/Home are unlabeled. (audit H10)
    private var accessibilityLabel: String {
        switch kind {
        case .back: "Back"
        case .home: "Home"
        // "User", not "Saved entries", since 0.8.5 (A1): the page this opens is
        // titled USER now and holds three shelves, of which SAVED is one.
        // VoiceOver naming a control after one of the three things behind it was
        // the same mismatch the title had.
        case .bookmarks: "User"
        }
    }

    /// This button's cap, taking the skin's per-button colour where the skin
    /// defines one (0.6.7, K2/K3) and the shared moulded cap otherwise. Home
    /// resolves through `accent` instead — see below.
    private var cap: ChassisControl {
        switch kind {
        case .back: skin.buttonSet?.back ?? skin.control
        case .bookmarks: skin.buttonSet?.bookmarks ?? skin.control
        // Never read for Home, which is built from a six-stop ramp; present so
        // the switch is exhaustive rather than optional-returning.
        case .home: skin.control
        }
    }

    /// Home's ramp: the console liveries give it its own, everything else uses
    /// the skin's single accent.
    private var homeAccent: ChassisAccent {
        skin.buttonSet?.home ?? skin.accent
    }

    private var gradient: LinearGradient {
        switch kind {
        case .back, .bookmarks:
            LinearGradient(colors: [cap.top, cap.bottom], startPoint: .top, endPoint: .bottom)
        case .home:
            LinearGradient(colors: [homeAccent.light, homeAccent.mid], startPoint: .top, endPoint: .bottom)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .back, .bookmarks: cap.edge
        case .home: homeAccent.edge
        }
    }

    // Glyphs scale with the button's own diameter rather than carrying fixed
    // points, so resizing the band does not leave the same small icon floating
    // in a bigger circle.
    @ViewBuilder
    private var icon: some View {
        switch kind {
        // The glyphs are Vinodex's own and stay that way (0.6.7, K2/K3): the
        // console liveries take the four *colours* and nothing else. No
        // reference shape is reproduced here.
        case .back:
            DexChromeGlyph(
                "backarrow", symbol: "chevron.left",
                size: size * 0.47, weight: .heavy, tint: cap.glyph
            )
        // The one control whose glyph a skin may replace (0.7.0, B2) —
        // HALLOWEEN's user button is a drawn pumpkin. `SkinMarkView` resolves
        // "the skin's mark, or the house symbol if it has none", so twenty of
        // twenty-one skins render exactly the `person.crop.circle` they always
        // did. See `ChassisSkin.userMark` for why this is not the console
        // liveries' colours-only caveat being reopened.
        case .bookmarks:
            SkinMarkView(
                mark: skin.userMark,
                fallback: "person.crop.circle",
                size: size * 0.44,
                tint: cap.glyph
            )
        case .home:
            Circle()
                .fill(LinearGradient(colors: [homeAccent.pale, homeAccent.bright], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(homeAccent.mid, lineWidth: 1))
                .padding(2)
                .overlay {
                    DexChromeGlyph(
                        "home", symbol: "house.fill",
                        size: size * 0.41, weight: .bold, tint: homeAccent.ink
                    )
                }
        }
    }
}

/// Chunky press feedback mirroring the web app's `active:scale` / `active:translate-y`.
///
/// The app's *screen* press — tiles, chips, rows. The moulded parts of the shell
/// take `ChassisPressStyle` instead (0.8.3, B2), which is deeper and drops the
/// light on the face; see `ChassisPress` for why the two are not one style.
struct DexPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    init(scale: CGFloat = 0.96) { self.scale = scale }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(DexMotion.press, value: configuration.isPressed)
    }
}
#endif
