#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

// The two row types `EntryDetailSections` and the country/state screens
// draw with, split out of EntryDetailScreen.swift (AUDIT **M30**). Neither
// was ever part of that screen's own view; both are shared. Nothing here
// changed in the move.

/// A related-entry row. Unresolved names render greyed and inert, mirroring
/// `isLinkable` in the web app — the common case at starter scale.
struct LinkedRow: View {
    /// Defaulted so the two construction sites need not change, but present so
    /// the row's one database read is not a hard `.shared` (AUDIT **M27**).
    var db: WineDatabase = .shared
    let title: String
    /// Nil when the name has no entry in the current selection.
    let entry: WineEntry?
    let fallbackColor: Color
    let resolved: Bool
    let action: () -> Void

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if let entry {
                        EntryIconWell(db: db, entry: entry, size: 38, cornerRadius: 6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(fallbackColor)
                            .frame(width: 38, height: 38)
                            .overlay(
                                DexIcon(
                                    iconID: db.icons.fallback,
                                    size: 22,
                                    color: Dex.stone600
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                            )
                    }
                }

                Text(title.uppercased())
                    .font(DexFont.retro(11))
                    // Not `.white`: this row's ground is `lcd.surface`, which is
                    // white in light mode — the label was white-on-white and
                    // vanished. This is the row FLAVOR PROFILE, NOTABLE GRAPES
                    // and every other linked list is built from.
                    .foregroundStyle(resolved ? lcd.text : lcd.disabledText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                if resolved {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Dex.stone600)
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(resolved ? Dex.stone700 : Dex.stone800, lineWidth: 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.98))
        .disabled(!resolved)
    }
}

/// Flag swatch used in the three-tile header row, and — larger — as the hero of
/// the country and state screens.
///
/// The size is a parameter rather than something the caller wraps in a `.frame`.
/// It used to be hard-coded at 52x32, and every call site that wanted a
/// different size put an outer frame around it: an outer frame does not resize
/// fixed content, so the country hero's `.frame(width: 96, height: 60)` was
/// simply centring a 52x32 flag in a 96x60 box, and the STATES rows' 40x26 box
/// was smaller than the flag it nominally sized.
struct FlagSwatch: View {
    /// Defaulted so the nine call sites need not change (AUDIT **M27**).
    var db: WineDatabase = .shared
    let country: String
    var width: CGFloat
    var height: CGFloat

    init(db: WineDatabase = .shared, country: String, width: CGFloat = 52, height: CGFloat = 32) {
        self.db = db
        self.country = country
        self.width = width
        self.height = height
    }

    /// Scaled off the swatch so a hero-sized flag does not carry the same 3pt
    /// radius and 2pt border a row-sized one does.
    private var corner: CGFloat { max(width * 0.06, 3) }
    private var border: CGFloat { max(width * 0.04, 2) }

    var body: some View {
        FlagImage(db: db, country: country)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(.white, lineWidth: border)
            )
    }
}
#endif
