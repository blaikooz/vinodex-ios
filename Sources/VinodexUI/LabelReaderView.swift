#if canImport(SwiftUI) && canImport(UIKit)
import PhotosUI
import SwiftUI
import VinodexCore

/// LABEL SCAN — photograph a bottle, read the label, match it against the
/// catalog (0.7.2, LR1).
///
/// **This file draws and nothing else.** Every decision — permissions, staging,
/// recognition, matching, what survives navigation — is in
/// `LabelReaderViewModel` and `LabelRecognitionService`. A `body` that also owns
/// an OCR call is the thing the architecture note in the spec is guarding
/// against, and it is what makes the matcher untestable.
///
/// The chrome is the blind-tasting screen's, deliberately: the same centred
/// prompt, the same `lcd.surface` rounded rectangles, the same accent-tinted
/// result card and the same full-width action buttons. These are the app's two
/// identification tools and they sit next to each other on the TOOLS shelf; a
/// second visual dialect between them would be the reader announcing that it
/// came from somewhere else.
public struct LabelReaderView: View {
    let onOpen: (WineEntry) -> Void

    @State private var model = LabelReaderViewModel()
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showingLibrary = false
    /// Drives the processing glyph's breath. A plain repeating opacity rather
    /// than `symbolEffect(.pulse)`: the effect API landed in iOS 17 and the
    /// floor *is* 17, so it would work — but nothing else in the app animates a
    /// symbol that way, and the LCD's idiom for waiting is something dimming and
    /// coming back.
    @State private var pulsing = false
    /// The tried shelf, for A2. `@State` on an `@Observable` so the button
    /// re-renders into its confirmed state the moment it writes.
    @State private var discovery = DiscoveryStore.shared
    /// How many this scan's button actually added, so the confirmation can say
    /// a number. Session-local and per-reading: SCAN AGAIN tears this view's
    /// result down, and a count carried across two bottles would be a lie.
    @State private var justMarked = 0
    /// Professor Vino (0.8.9c, E2). Two triggers land here: `firstScan` on a
    /// confident read, and `firstTried` when this screen is the one that puts
    /// the first wine on the shelf — a scan-first player never taps the entry
    /// screen's pill, and firing it only there would have lost them the line.
    @State private var vino = VinoPresenter.shared
    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private let db = WineDatabase.shared

    public init(onOpen: @escaping (WineEntry) -> Void) {
        self.onOpen = onOpen
    }

    public var body: some View {
        ZStack {
            DexScreenBackground()

            GeometryReader { geo in
                ScrollView {
                    content
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 22)
                        .frame(minHeight: geo.size.height, alignment: .center)
                }
            }
        }
        .onAppear { model.restore() }
        // `PhotosPicker` runs out-of-process, so the library route needs no
        // permission of its own and cannot be denied — which is why it is also
        // the fallback offered whenever the camera is refused.
        .photosPicker(isPresented: $showingLibrary, selection: $pickedPhoto, matching: .images)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                pickedPhoto = nil
                await model.process(imageData: data ?? Data())
            }
        }
        .fullScreenCover(isPresented: $model.showingCamera) {
            CameraCapture(
                onCapture: { data in
                    model.showingCamera = false
                    Task { await model.process(imageData: data) }
                },
                onCancel: { model.showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .animation(DexMotion.overlay, value: model.phase)
        // **The first successful label read** (0.8.9c, E2).
        //
        // On `.identified` only. An ambiguous shortlist or a no-match is the
        // reader failing to do the thing his line is about ("I read wine
        // beautifully"), and spending the once-ever bubble on a miss would be
        // both a lie and unrecoverable.
        //
        // Watched on the phase rather than called from `results(_:)`, which is a
        // view builder and would re-fire on every render of the results card.
        .onChange(of: model.phase) { _, phase in
            guard case .result(let reading) = phase, reading.outcome == .identified else { return }
            vino.fireOnce(.firstScan)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            chooser
        case .processing(let stage):
            processing(stage)
        case .result(let reading):
            results(reading)
        case .failed(let error):
            failure(error)
        }
    }

    // MARK: - Idle

    private var chooser: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 74, weight: .semibold))
                .foregroundStyle(lcd.accent)

            Text("READ A LABEL")
                .font(DexFont.retro(20))
                .tracking(1)
                .foregroundStyle(lcd.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Point the camera at the front of the bottle. Everything is read on this device — nothing leaves your phone.")
                .font(DexFont.mono(21))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            bigButton("TAKE PHOTO", symbol: "camera.fill", tint: lcd.accent) {
                Task { await model.requestCamera() }
            }
            bigButton("CHOOSE FROM LIBRARY", symbol: "photo.on.rectangle", tint: lcd.subtext) {
                showingLibrary = true
            }

            if let notice = model.cameraNotice {
                // Inline rather than a `DexAlert`: the library button directly
                // above is still a working way to use this screen, and a modal
                // over it would say the tool was broken when only one of its two
                // doors is.
                noticeCard(notice.message, symbol: "exclamationmark.triangle.fill", tint: Dex.amber400)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Processing

    /// The staged readout. Five blocks, one per `LabelReaderStage`, filling in
    /// as the pipeline advances — the LCD's own vocabulary rather than a system
    /// spinner, which would be the one piece of stock iOS chrome anywhere in the
    /// app.
    private func processing(_ stage: LabelReaderStage) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(lcd.accent)
                // A slow breath rather than a spin: nothing in this app rotates,
                // and a rotating indicator is the one piece of stock iOS chrome
                // the chassis has managed to avoid everywhere else.
                .opacity(pulsing ? 1 : 0.45)
                .animation(
                    .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                    value: pulsing
                )
                .onAppear { pulsing = true }
                .onDisappear { pulsing = false }

            Text(stage.title)
                .font(DexFont.retro(16))
                .tracking(1)
                .foregroundStyle(lcd.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(LabelReaderStage.allCases, id: \.rawValue) { step in
                    let reached = step.progress <= stage.progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(reached ? lcd.accent : lcd.surfaceEdge.opacity(0.5))
                        .frame(height: 10)
                }
            }
            .padding(.horizontal, 8)

            Text("\(Int(stage.progress * 100))%")
                .font(DexFont.retro(12))
                .tracking(2)
                .foregroundStyle(lcd.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.accent.opacity(0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.accent.opacity(0.45), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stage.title) \(Int(stage.progress * 100)) percent")
    }

    // MARK: - Results

    @ViewBuilder
    private func results(_ reading: LabelReading) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Three states since 0.7.9 (D-a) — see `LabelReading.Outcome`. The
            // middle one is why: a label narrowed to a country and a shortlist
            // of its regions was being told it did not match anything.
            switch reading.outcome {
            case .identified: confidentCard(reading)
            case .ambiguous: shortlistCard(reading)
            case .unrecognized: noMatchCard(reading)
            }

            if !reading.grapeIDs.isEmpty {
                entrySection("POSSIBLE GRAPES", symbol: "circle.grid.3x3.fill", ids: reading.grapeIDs)
            }
            if !reading.styleIDs.isEmpty {
                entrySection("POSSIBLE STYLES", symbol: "wineglass.fill", ids: reading.styleIDs)
            }
            // Both unconfident states earn the shortlist; the identified one
            // carries no suggestions to show (`LabelRecognitionService` only
            // builds them when the reading falls short).
            if reading.outcome != .identified {
                suggestionSections(reading)
            }

            markTriedControl(reading)

            extractedText(reading)

            bigButton("SCAN AGAIN", symbol: "arrow.counterclockwise", tint: lcd.subtext) {
                // Cleared with the reading: SCAN AGAIN is the only way back to
                // the camera from a result, so this is the one place a carried
                // count could become a lie about the next bottle.
                justMarked = 0
                model.reset()
            }
        }
    }

    // MARK: Scan to tried (0.8.9b, A2)

    /// One tap that marks everything this read identified as tried.
    ///
    /// **The spec says "on a successful Label Reader result, mark the matched
    /// grapes + style as tried", and this asks first.** The reason is on the
    /// screen directly above: the two lists are headed POSSIBLE GRAPES and
    /// POSSIBLE STYLES, and they mean it — `grapeIDs` is usually *inferred from
    /// the place* rather than read off the bottle, so a Bordeaux label produces
    /// six grapes of which the bottle held some unknown subset, and a scan taken
    /// in a shop out of curiosity produces the same six. Writing those silently
    /// would move the rank ladder, stamp the activity graph and count toward
    /// both completion badges on evidence the app itself calls possible, and
    /// undoing it means visiting seven entry pages.
    ///
    /// One tap for six grapes and a style is still the fast path the spec wants
    /// — the alternative it is being measured against is seven separate visits,
    /// not zero taps. What it is not is the app deciding on the user's behalf
    /// that they drank something.
    ///
    /// The button says what it will do and then what it did, and it goes away
    /// when there is nothing left to add — a control that stays lit after its
    /// work is done invites a second press that would find nothing to do.
    /// `LabelReading.triedCandidateIDs` decides eligibility and is tested in
    /// Core; the marking goes through `DiscoveryStore`, which is the tried
    /// shelf, so a scanned tasting is dated, earns stamps and clears the
    /// wishlist exactly as a hand-marked one does.
    @ViewBuilder
    private func markTriedControl(_ reading: LabelReading) -> some View {
        let candidates = reading.triedCandidateIDs
        let pending = candidates.filter { !discovery.isTried($0) }
        if !candidates.isEmpty {
            VStack(spacing: 8) {
                if pending.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 19, weight: .bold))
                        Text(justMarked > 0 ? markedLabel : "ALREADY ON YOUR TRIED SHELF")
                            .font(DexFont.retro(12))
                            .tracking(1)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(lcd.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.accent.opacity(0.1)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(lcd.accent.opacity(0.5), lineWidth: 2)
                    )
                    .accessibilityElement(children: .combine)
                } else {
                    bigButton(
                        pending.count == 1 ? "I DRANK THIS" : "I DRANK THIS \u{2014} MARK \(pending.count) TRIED",
                        symbol: "checkmark.circle",
                        tint: Dex.yellow
                    ) {
                        justMarked = discovery.markTried(ids: pending).count
                        // Only when this tap actually shelved something - the
                        // button is hidden once everything is marked, but a
                        // race or a repeat must not spend the line on nothing.
                        if justMarked > 0 { vino.fireOnce(.firstTried) }
                    }
                    Text("Adds them to your tried shelf, where the passport and INSIGHT read from.")
                        .font(DexFont.mono(13))
                        .foregroundStyle(lcd.subtext)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var markedLabel: String {
        justMarked == 1 ? "MARKED 1 TRIED" : "MARKED \(justMarked) TRIED"
    }

    /// The identification, in the spec's own row order — producer, region,
    /// country, then whatever else was resolved — with the confidence last.
    private func confidentCard(_ reading: LabelReading) -> some View {
        VStack(spacing: 14) {
            Text("BEST MATCH")
                .font(DexFont.retro(14))
                .tracking(2)
                .foregroundStyle(Dex.yellow)

            // The country's flag is the one image a label read can offer with
            // certainty, and it is how every other place-shaped screen in the
            // app opens.
            if let country = reading.match(.country)?.name {
                FlagSwatch(country: country, width: 132, height: 84)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
            }

            VStack(spacing: 8) {
                ForEach(reading.matches) { match in
                    row(match)
                }
            }

            confidenceBar(reading.score)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.accent.opacity(0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.accent.opacity(0.45), lineWidth: 2)
        )
    }

    /// One resolved field. Tappable when it resolves to an entry the user can
    /// open, flat text when it does not — the same rule the detail screen's
    /// cross-links follow, since a country and a vintage have no page to go to.
    @ViewBuilder
    private func row(_ match: LabelMatch) -> some View {
        let entry = match.entryID.flatMap { db.entry(id: $0) }

        HStack(alignment: .top, spacing: 10) {
            Text(match.field.title)
                .font(DexFont.retro(10))
                .tracking(1)
                .foregroundStyle(lcd.subtext)
                .frame(width: 96, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(match.name)
                    .font(DexFont.mono(22))
                    .foregroundStyle(lcd.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                // Where a field came from, whenever it was not simply read off
                // the bottle. Both captions exist because the alternative is a
                // screen that presents a guess and a deduction in the same
                // typeface as a fact — and the score, which discounts both,
                // is not visible per row.
                if match.isInferred {
                    Text("from \(match.readAs)")
                        .font(DexFont.mono(15))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !match.isExact {
                    Text("read as “\(match.readAs)”")
                        .font(DexFont.mono(15))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if entry != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(lcd.subtext)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(lcd.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 4).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard let entry else { return }
            Haptics.select()
            onOpen(entry)
        }
    }

    /// The score, as a bar and a number.
    ///
    /// Coloured by band rather than by a gradient so the three states read at a
    /// glance — a 94 and a 31 should not be the same shade of anything.
    private func confidenceBar(_ score: Int) -> some View {
        let tint: Color = score >= 70 ? Dex.green500 : (score >= LabelConfidence.floor ? Dex.amber400 : Dex.red500)
        return VStack(spacing: 6) {
            HStack {
                Text("CONFIDENCE")
                    .font(DexFont.retro(11))
                    .tracking(1)
                    .foregroundStyle(lcd.subtext)
                Spacer(minLength: 4)
                Text("\(score)%")
                    .font(DexFont.retro(16))
                    .foregroundStyle(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(lcd.surfaceEdge.opacity(0.5))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(score) / 100)
                }
            }
            .frame(height: 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confidence \(score) percent")
    }

    /// The spec's no-match state: says so plainly, then hands over everything it
    /// did find rather than an apology.
    ///
    /// **Narrowed in 0.7.9 (D-a) to mean what it says.** This card used to
    /// answer every unconfident reading, including the ones where the reader had
    /// narrowed the bottle to a country and five of its regions — telling a user
    /// "no match" while a list of candidates sat directly beneath it. That case
    /// is `shortlistCard` now; this is the genuine nothing.
    private func noMatchCard(_ reading: LabelReading) -> some View {
        outcomeCard(
            reading,
            symbol: "questionmark.diamond.fill",
            tint: Dex.amber400,
            headline: "NO CONFIDENT MATCH FOUND.",
            body: "Here is everything the label gave up. A straighter, closer photo of the front label usually settles it."
        )
    }

    /// **The state between a result and a failure** (0.7.9, D-a).
    ///
    /// The reader could not name the bottle but did reach real entries — a
    /// country, a near-miss region, a grape that did not carry the score over
    /// the floor. That is a shortlist, and a shortlist is a usable answer: the
    /// common shape is a French label naming a region the catalog holds and a
    /// producer it never will, which the on-device matcher is structurally
    /// incapable of finishing (there is no producer entity — see
    /// `LabelField.producer`). Telling the user it failed threw that away.
    ///
    /// Cyan rather than amber, because this is information rather than a
    /// warning, and the copy points at the sections below instead of at the
    /// camera — retaking the photo will not add a producer index.
    private func shortlistCard(_ reading: LabelReading) -> some View {
        outcomeCard(
            reading,
            symbol: "list.bullet.rectangle.fill",
            tint: Dex.cyan300,
            headline: "NARROWED IT DOWN.",
            body: "Not enough to name the bottle, but these are the candidates the catalog can see. Open one to check it against what you are holding."
        )
    }

    /// The shared chrome for both. One shape, two tints, so the difference the
    /// user notices is the sentence rather than the layout.
    private func outcomeCard(
        _ reading: LabelReading,
        symbol: String,
        tint: Color,
        headline: String,
        body: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(tint)

            Text(headline)
                .font(DexFont.retro(16))
                .tracking(1)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(body)
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if !reading.matches.isEmpty {
                VStack(spacing: 8) {
                    ForEach(reading.matches) { match in
                        row(match)
                    }
                }
            }

            confidenceBar(reading.score)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.5), lineWidth: 2)
        )
    }

    @ViewBuilder
    private func suggestionSections(_ reading: LabelReading) -> some View {
        if !reading.suggestedCountries.isEmpty {
            section("SUGGESTED COUNTRIES", symbol: "flag.fill") {
                FlowLayout(spacing: 6) {
                    ForEach(reading.suggestedCountries, id: \.self) { country in
                        summaryChip(country.uppercased(), db.palette.chip(country: country))
                    }
                }
            }
        }
        if !reading.suggestedRegionIDs.isEmpty {
            entrySection("SUGGESTED REGIONS", symbol: "map.fill", ids: reading.suggestedRegionIDs)
        }
    }

    /// The raw OCR, always available.
    ///
    /// Shown on a confident read too, not only on a failure: it is the only way
    /// a user can tell a wrong answer from a wrong *photo* — a reading that
    /// looks mad is usually a label half out of frame, and this is where that
    /// becomes visible. Last section on the page, so it costs a scroll rather
    /// than a glance.
    private func extractedText(_ reading: LabelReading) -> some View {
        section("EXTRACTED TEXT", symbol: "text.alignleft") {
            VStack(alignment: .leading, spacing: 4) {
                if reading.recognizedText.isEmpty {
                    Text("Nothing was legible in that image.")
                        .font(DexFont.mono(18))
                        .foregroundStyle(lcd.subtext)
                } else {
                    ForEach(Array(reading.recognizedText.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(DexFont.mono(17))
                            .foregroundStyle(lcd.bodyText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(lcd.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 4).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
            )
        }
    }

    // MARK: - Failure

    private func failure(_ error: LabelReadError) -> some View {
        VStack(spacing: 16) {
            noticeCard(error.message, symbol: "exclamationmark.triangle.fill", tint: Dex.red500)
            bigButton("TRY AGAIN", symbol: "arrow.counterclockwise", tint: lcd.accent) {
                model.reset()
            }
        }
    }

    // MARK: - Shared chrome
    //
    // Lifted from `ScannerScreen`'s own helpers rather than reinvented — same
    // surfaces, same rims, same press style. See this type's note.

    private func noticeCard(_ message: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // `camera` and `home` both land here through `bigButton` (0.8.1,
            // J3); anything else falls back to its symbol.
            DexChromeGlyph(Self.buttonArt[symbol] ?? symbol, symbol: symbol, size: 18, weight: .bold)
                .foregroundStyle(tint)
            Text(message)
                .font(DexFont.mono(18))
                .foregroundStyle(lcd.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.5), lineWidth: 2)
        )
    }

    private func section<C: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(lcd.accent)
                Text(title)
                    .font(DexFont.retro(12))
                    .tracking(1)
                    .foregroundStyle(lcd.accent)
            }
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) { lcd.accent.opacity(0.4).frame(height: 2) }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A titled list of entries, each opening its own page.
    private func entrySection(_ title: String, symbol: String, ids: [String]) -> some View {
        section(title, symbol: symbol) {
            VStack(spacing: 8) {
                ForEach(ids.compactMap { db.entry(id: $0) }) { entry in
                    Button {
                        Haptics.select()
                        onOpen(entry)
                    } label: {
                        HStack(spacing: 10) {
                            EntryIconWell(entry: entry, size: 44, cornerRadius: 8)
                            Text(entry.name.uppercased())
                                .font(DexFont.retro(13))
                                .foregroundStyle(lcd.text)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(lcd.subtext)
                        }
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(lcd.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(lcd.surfaceEdge, lineWidth: 1)
                        )
                    }
                    .buttonStyle(DexPressStyle(scale: 0.98))
                }
            }
        }
    }

    private func summaryChip(_ label: String, _ chip: Palette.Chip?) -> some View {
        let resolved = chip ?? Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
        return Text(label)
            .font(DexFont.retro(11))
            .foregroundStyle(Color(dexHex: resolved.text))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(dexHex: resolved.bg)))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(dexHex: resolved.border), lineWidth: 1)
            )
    }

    /// SF Symbol -> drawn button face, for the symbols `bigButton` is called
    /// with that have one (0.8.1, J3). A map rather than a parameter because
    /// every caller already passes the symbol and none of them should have to
    /// know whether art exists for it.
    private static let buttonArt: [String: String] = [
        "camera.fill": "camera",
        "house.fill": "home",
    ]

    private func bigButton(
        _ label: String,
        symbol: String? = nil,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.screenTap()
            action()
        } label: {
            HStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 21, weight: .bold))
                }
                Text(label)
                    .font(DexFont.retro(14))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(tint)
            .padding(.vertical, 19)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.6), lineWidth: 2)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }
}
#endif
