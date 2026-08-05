#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The stylised cards B1–B3 export (0.7.8, B).
///
/// ## Why these are a still frame and not `DeviceChassis`
///
/// B3 asks for the card to be "framed with the Vinodex device chassis", and the
/// tempting reading is to put `DeviceChassis` itself through `ImageRenderer`.
/// That was tried on paper and rejected, because rendering it off-screen is not
/// the same as displaying it, and it fails in ways that would ship silently:
///
/// - Its `body` opens `GeometryReader { geo in … geo.safeAreaInsets.top }`.
///   `ImageRenderer` supplies no safe-area insets, so the island strip collapses
///   to its minimum and the whole vertical layout differs from the device.
/// - `StretchedWordmark` measures itself in `onAppear` and stores the result in
///   `@State`. A one-shot render never runs `onAppear`, so the measurement stays
///   `.zero` and the wordmark draws unstretched.
/// - `MarqueeBanner`'s text is populated by `task`/`onChange` into `@State`, so
///   the marquee would export **blank**.
/// - `PulseGlow` animates `@State` with a repeating `withAnimation`; in a single
///   frame every lamp renders at its dim extreme.
/// - `Screensaver` and `MarqueeLampChooser` branch on live app state, so an
///   export could catch the chooser open.
///
/// Every one of those is a real defect in an image somebody posts. So the card
/// takes the *tokens* rather than the view: `ChassisLook` for the shell and its
/// parts, `LcdMode` for the panel, the real `ChamferedPanel` silhouette (made
/// public for this), and `ScanlineOverlay`. The result is deterministic, and it
/// still reads as the user's own device because every colour on it is theirs.
struct ShareCardFrame<Content: View>: View {
    let caption: String
    @ViewBuilder let content: () -> Content

    /// Resolved from `UserDefaults` rather than `@AppStorage`. The card is
    /// rendered off-screen from a call site, not mounted in a view tree, and a
    /// plain read is one less thing depending on the renderer's environment.
    private var build: DeviceBuild { DeviceBuild.active() }
    private var look: ChassisLook { ChassisLook(build: build) }
    private var lcd: LcdMode { LcdMode.current }

    var body: some View {
        ZStack {
            look.underlay

            VStack(spacing: 0) {
                screen
                bottomStrip
            }
            .padding(16)
            .background(
                ChamferedPanel(corner: 26, chamfer: 18)
                    .fill(look.body)
                    .overlay(
                        ChamferedPanel(corner: 26, chamfer: 18)
                            .strokeBorder(look.panelEdge, lineWidth: 2)
                    )
            )
            .padding(18)
        }
    }

    /// The LCD, with the same monochrome pass `DeviceChassis.innerBezel`
    /// applies — a card exported from an AMBER device should be amber, because
    /// the point of carrying the user's skin onto the card is that it is their
    /// device that shows up in somebody else's feed.
    private var screen: some View {
        ZStack {
            lcd.panelGround
            content()
                .padding(14)
            ScanlineOverlay()
                .opacity(DexMetrics.scanlineOpacity)
        }
        .grayscale(lcd.monochromeTint == nil ? 0 : 1)
        .colorMultiply(lcd.monochromeTint ?? .white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Dex.stone800, lineWidth: 3)
        )
    }

    /// The wordmark, the caption and the running version.
    ///
    /// `AppVersion.display` rather than a literal: this string leaves the
    /// device, and `AppVersion.placeholders` exists because xtool stamps a
    /// `1.0.0` that is not true. A card claiming a version the build never
    /// chose is exactly the mistake that denylist was written for.
    private var bottomStrip: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // `grill`, which is the ink the device's own bottom strip prints its
            // wordmark in — see `StretchedWordmark(ink: skin.grill)`. Not
            // `userMark`: that is a `SkinMark?`, an optional *emblem*, not a
            // colour, and it is the shell's badge rather than its lettering.
            Text(ShareCard.wordmark)
                .font(DexFont.retro(15))
                .tracking(3)
                .foregroundStyle(look.grill)

            Text(caption)
                .font(DexFont.mono(12))
                .foregroundStyle(look.grill.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 4)

            Text(AppVersion.display)
                .font(DexFont.mono(12))
                .foregroundStyle(look.grill.opacity(0.65))
        }
        .padding(.top, 12)
        .padding(.horizontal, 2)
    }
}

// MARK: - B1, an encyclopedia entry

/// One catalog entry as a card.
struct EntryShareCard: View {
    let entry: WineEntry

    private var lcd: LcdMode { LcdMode.current }

    var body: some View {
        ShareCardFrame(caption: entry.category.rawValue) {
            VStack(alignment: .leading, spacing: 12) {
                EntryIconWell(entry: entry, size: 104, cornerRadius: 12)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(entry.name)
                    .font(DexFont.retro(21))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)

                if let origin = entry.origin, !origin.isEmpty {
                    Text(origin.uppercased())
                        .font(DexFont.retro(11))
                        .tracking(1.5)
                        .foregroundStyle(lcd.accent)
                }

                // Trimmed rather than scrolled: a card is a fixed rectangle and
                // an entry's prose is not. `lineLimit` does the cut so the
                // sentence ends where the renderer says it does.
                Text(entry.entryDescription)
                    .font(DexFont.mono(14))
                    .foregroundStyle(lcd.bodyText)
                    .lineSpacing(2)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - B2, the player's profile

/// The passport as a card: rank, completion, the four counts, the streak.
struct ProfileShareCard: View {
    let card: ShareCard.Profile

    private var lcd: LcdMode { LcdMode.current }

    var body: some View {
        ShareCardFrame(caption: card.device) {
            VStack(alignment: .leading, spacing: 10) {
                Text(card.rank)
                    .font(DexFont.retro(19))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(card.completionPercent)%")
                        .font(DexFont.retro(40))
                        .foregroundStyle(lcd.text)
                    Text("COLLECTED")
                        .font(DexFont.retro(11))
                        .tracking(1.5)
                        .foregroundStyle(lcd.subtext)
                }

                bar

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    stat("GRAPES", "\(card.triedGrapes)/\(card.totalGrapes)")
                    stat("STYLES", "\(card.triedStyles)/\(card.totalStyles)")
                    stat("COUNTRIES", "\(card.countries)")
                    stat("STAMPS", "\(card.badgesEarned)/\(card.badgesTotal)")
                }

                if card.streak > 0 {
                    Text("DAILY STREAK  \(card.streak)   BEST  \(card.bestStreak)")
                        .font(DexFont.retro(11))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(lcd.well)
                Capsule()
                    .fill(lcd.accent)
                    .frame(width: max(0, geo.size.width * card.completion))
            }
        }
        .frame(height: 10)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(DexFont.retro(15))
                .foregroundStyle(lcd.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(DexFont.retro(9))
                .tracking(1)
                .foregroundStyle(lcd.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 5).fill(lcd.surface))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(lcd.surfaceEdge, lineWidth: 1))
    }
}

// MARK: - B3, a passport milestone

/// "SOMMELIER UNLOCKED", "42/171 GRAPES COLLECTED".
struct AchievementShareCard: View {
    let achievement: ShareCard.Achievement
    var symbol: String = "rosette"

    private var lcd: LcdMode { LcdMode.current }

    var body: some View {
        ShareCardFrame(caption: "PASSPORT") {
            VStack(spacing: 16) {
                Spacer(minLength: 0)

                Image(systemName: symbol)
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(lcd.accent)

                Text(achievement.headline)
                    .font(DexFont.retro(22))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)

                Text(achievement.caption)
                    .font(DexFont.mono(14))
                    .foregroundStyle(lcd.subtext)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
#endif
