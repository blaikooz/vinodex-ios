#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// A row in the encyclopedia list.
///
/// The icon slot is a placeholder colour block until the ~30 game-icons are
/// rasterised — deliberately obvious rather than an SF Symbol stand-in, so it
/// cannot be mistaken for finished work.
struct EntryTileView: View {
    /// Defaulted so the row's many construction sites need not change; present
    /// so the icon well it builds is not pinned to `.shared` (AUDIT **M27**).
    var db: WineDatabase = .shared
    let entry: WineEntry
    let palette: Palette
    /// Free-tier gating. A locked row still renders and is still tappable —
    /// tapping it is how the upgrade prompt is reached — it just reads as
    /// unavailable.
    var locked: Bool = false
    /// Whether this entry is on the TRIED shelf (0.8.91, B2).
    ///
    /// **Passed in rather than read from `BookmarkStore` here.** The store is
    /// observable, so a row that read it would make every listing re-render every
    /// row on every bookmark change; the caller reads it once and hands each row
    /// its own answer. It is also what keeps this view free of a store
    /// dependency, which is why it can be used by the exam and the quiz — two
    /// screens where the tried state is deliberately not shown.
    var tried: Bool = false
    /// Off in the saved list, where the row's top-right corner belongs to the
    /// remove button.
    var showsChevron: Bool = true
    let action: () -> Void

    /// The eight stored settings, as one model (arch **A17**).
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    init(
        entry: WineEntry,
        palette: Palette,
        locked: Bool = false,
        tried: Bool = false,
        showsChevron: Bool = true,
        action: @escaping () -> Void
    ) {
        self.entry = entry
        self.palette = palette
        self.locked = locked
        self.tried = tried
        self.showsChevron = showsChevron
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 12) {
                iconSlot

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.name.uppercased())
                        .font(DexFont.retro(13))
                        .foregroundStyle(lcd.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    FlowLayout(spacing: 5) {
                        ForEach(entry.tileChips) { chip in
                            ChipView(label: chip.label, chip: palette.resolve(chip))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Dex.yellow)
                } else if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Dex.stone600)
                } else {
                    Color.clear.frame(width: 34)
                }
            }
            .padding(8)
            .frame(minHeight: 72)
            // Desaturated rather than dimmed to near-invisible: a locked row
            // still has to be readable, because seeing what is behind the
            // paywall is the entire point of showing it.
            .saturation(locked ? 0.15 : 1)
            .opacity(locked ? 0.55 : 1)
            .background(lcd.surface)
            // **The tried border** (0.8.91, B2). The row's own edge recoloured
            // rather than a second ring outside it: one border is what the tile
            // has always had, and a rule that adds an outline changes the row's
            // height and makes a tried row a different size from an untried one
            // in the same list.
            //
            // `Dex.green` is a fixed hex, like the OWNED badge and the complete
            // progress bar it matches. Under the monochrome LCD modes it
            // flattens with everything else — which is correct, because those
            // modes have one phosphor and a green that survived them would be
            // the only colour on the screen.
            //
            // Locked wins over tried, and cannot collide with it in practice:
            // nothing behind the paywall can be on your shelf. Ordered anyway,
            // because "cannot happen" is how a border ends up drawn in two
            // colours at once.
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(triedAwareEdge, lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
    }

    private var triedAwareEdge: Color {
        if locked { return lcd.surfaceEdge.opacity(0.6) }
        return tried ? Dex.green : lcd.surfaceEdge
    }

    private var iconSlot: some View {
        EntryIconWell(db: db, entry: entry, size: DexMetrics.iconWell, cornerRadius: 8)
    }
}

#endif
