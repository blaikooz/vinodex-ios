#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// The stamp series, laid out as a collection (0.8.6, C3/C4).
///
/// **Why this is a screen and not a bigger grid on the passport.** The passport
/// counts: eight badge tiles saying earned or not, four stat tiles saying how
/// many, three progress sections saying how far. The stamps are the only things
/// on it that are *objects* — drawn, franked, each with a story and a
/// denomination — and at the tile size that page can spare they were reduced to
/// a symbol and two words. C3 gives them a page where the drawing is the content
/// and the words are the caption, which is what a collection is.
///
/// **Every stamp appears, earned or not**, which is the difference between an
/// album and a trophy shelf. An unearned stamp shows its silhouette and what it
/// would take, because a series with holes in it is the thing that makes you
/// want to fill them; a series that only shows what you already have tells you
/// nothing you did not know. The unearned face is desaturated and dimmed rather
/// than hidden or padlocked — the drawing is the hook.
///
/// Reads the same `Passport.compute` the passport screen does. Nothing here is
/// computed; the screen owns layout and nothing else, exactly like
/// `PassportScreen`.
public struct StampCollectionScreen: View {
    @State private var bookmarks = BookmarkStore.shared
    @State private var streak = StreakStore.shared
    @State private var progress = QuizProgress.shared
    private let db = WineDatabase.shared

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    /// The stamp whose story is open. Same idiom as the back plate's, and the
    /// same `DexAlert`: a stamp's `info` is one paragraph, and a paragraph is
    /// what that modal is for.
    @State private var openStamp: BackPlateStamp?

    /// The rendered card waiting on the share sheet (0.8.7, B1).
    ///
    /// Arrived with the passport's badge grid, which is where an earned stamp
    /// was shareable from until B1 removed the grid. The affordance follows the
    /// object rather than dying with the tile that used to carry it — this is
    /// now the only page in the app that draws all eight.
    @State private var sharePayload: SharePayload?

    public init() {}

    /// Announce one stamp (0.7.8, B3/B4 — moved here in 0.8.7, B1).
    ///
    /// Reads `StampCatalog` for the symbol rather than carrying a table of its
    /// own. The passport had one, and after eight releases it disagreed with the
    /// catalog on two of the eight badges: FIRST SIP was a drop there and a
    /// wineglass here, REGION COMPLETE a filled map there and a pin here. A
    /// share card is a picture of a thing the app also draws, so it reads the
    /// record the app draws it from.
    ///
    /// **The whole stamp goes now, not its symbol (0.8.8, F1).** The paragraph
    /// above already had the right principle — "a share card is a picture of a
    /// thing the app also draws" — and was applying it one field short: it
    /// handed over `fallbackSymbol`, which is the stand-in for the drawing
    /// rather than the drawing. Passing the record itself lets the card call
    /// `BackPlateStampView`, the same view the collection tile above and the
    /// unlock prompt both use, so the three surfaces are now three sizes of one
    /// object instead of two pictures and a placeholder. `symbol:` is still
    /// passed for the milestones that are not stamps — see the card.
    ///
    /// `blurb` is the Passport's — what it took to earn — rather than the
    /// stamp's `info`, which is the joke. A card that goes to somebody else says
    /// what was achieved.
    private func share(_ stamp: BackPlateStamp, blurb: String) {
        Haptics.select()
        let achievement = ShareCard.Achievement.unlocked(stamp.title, blurb: blurb)
        if let image = ShareCardRenderer.image({
            AchievementShareCard(
                achievement: achievement,
                symbol: stamp.fallbackSymbol,
                stamp: stamp
            )
        }) {
            sharePayload = .image(image, title: stamp.title)
        }
    }

    private var passport: Passport {
        Passport.compute(
            tried: bookmarks.ids(on: .tried),
            in: db,
            bestStreak: streak.best,
            highestTier: progress.highestUnlocked,
            triedDays: bookmarks.triedDayLog
        )
    }

    /// Two columns. Three fits the width and would put the drawings back at the
    /// size the passport already draws them at, which is the thing this page
    /// exists not to do.
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    public var body: some View {
        let passport = passport
        let earned = Set(passport.badges.filter(\.earned).map(\.id))
        let blurbs = Dictionary(uniqueKeysWithValues: passport.badges.map { ($0.id, $0.blurb) })

        return ZStack {
            DexScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(earnedCount: earned.count, total: passport.badges.count)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(StampCatalog.all) { stamp in
                            tile(
                                stamp,
                                earned: earned.contains(stamp.id),
                                blurb: blurbs[stamp.id] ?? stamp.info
                            )
                        }
                    }
                }
                .padding(14)
            }
        }
        .shareCard($sharePayload)
        .overlay {
            if let stamp = openStamp {
                DexAlert(
                    title: stamp.title,
                    message: stamp.info,
                    confirmLabel: "OK",
                    cancelLabel: nil,
                    onConfirm: { openStamp = nil },
                    onCancel: { openStamp = nil }
                )
            }
        }
        .animation(DexMotion.overlay, value: openStamp)
    }

    private func header(earnedCount: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COLLECTION")
                .font(DexFont.retro(14))
                .tracking(1.5)
                .foregroundStyle(lcd.accent)
            Text("\(earnedCount) OF \(total) ISSUED. TAP FOR ITS STORY, OR SHARE ONE YOU HOLD.")
                .font(DexFont.mono(15))
                .foregroundStyle(lcd.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { lcd.accent.opacity(0.45).frame(height: 2) }
    }

    /// One album slot: the stamp itself, its title, and what it took.
    private func tile(_ stamp: BackPlateStamp, earned: Bool, blurb: String) -> some View {
        let ink = Color(dexHex: stamp.colorHex)

        return Button {
            Haptics.select()
            openStamp = stamp
        } label: {
            VStack(spacing: 10) {
                // Bigger than anywhere else it appears — the plate draws it at
                // 72x66 among eight other leavings and this page has one job.
                BackPlateStampView(stamp: stamp, width: 128, height: 116)
                    // Unearned: the drawing, drained and dimmed. `saturation`
                    // rather than a lock glyph, so the silhouette still tells you
                    // what the stamp is a picture of — see the type's note.
                    .saturation(earned ? 1 : 0.12)
                    .opacity(earned ? 1 : 0.42)

                Text(stamp.title)
                    .font(DexFont.retro(11))
                    .tracking(1)
                    .foregroundStyle(earned ? lcd.text : lcd.disabledText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)

                Text(earned ? stamp.denomination : blurb)
                    .font(DexFont.mono(14))
                    .foregroundStyle(earned ? ink : lcd.subtext)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        earned ? ink.opacity(0.55) : lcd.surfaceEdge,
                        lineWidth: earned ? 2 : 1
                    )
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
        .accessibilityLabel(
            "\(stamp.title). \(earned ? "Earned, \(stamp.denomination)." : "Not yet earned. \(blurb)")"
        )
        .accessibilityHint("Opens its story.")
        // **A sibling of the tile, not a control inside it** (0.8.7, B1). The
        // face is already a `Button`, and a second `Button` in its *label* is
        // inside another button's hit region — the outer one wins and the share
        // never fires. An `.overlay` on the finished button is a peer in the
        // hit-test tree, drawn above, so it takes the touches that land on it
        // and the rest of the card still opens the story.
        //
        // Unearned stamps get no control, for 0.7.8 B4's reason: there is
        // nothing yet to announce.
        .overlay(alignment: .topTrailing) {
            if earned {
                Button { share(stamp, blurb: blurb) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(lcd.accent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(lcd.buttonWell))
                        .overlay(Circle().strokeBorder(ink.opacity(0.55), lineWidth: 1.5))
                }
                .buttonStyle(DexPressStyle(scale: 0.9))
                .padding(6)
                .accessibilityLabel("Share \(stamp.title)")
            }
        }
    }
}
#endif
