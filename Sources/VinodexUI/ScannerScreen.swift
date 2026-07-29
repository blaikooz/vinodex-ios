#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import VinodexCore

/// The scanner: five questions about the glass in front of you, then a
/// deduction.
///
/// The whole flow lives in one view with a `Step` cursor rather than as pushed
/// `DexRoute`s. That is the opposite of the choice made for the settings
/// sections, and for the opposite reason: settings panels are independent
/// destinations, whereas these steps share one accumulating answer. Pushing
/// routes would put `GrapeScanCriteria` somewhere global and make the chassis
/// Back button unwind the questionnaire one answer at a time — here Back means
/// "leave the scanner", and the in-screen back arrow steps between questions.
public struct ScannerScreen: View {
    let onOpen: (WineEntry) -> Void

    @State private var step: Step = .color
    @State private var criteria = GrapeScanCriteria()

    @AppStorage(LcdMode.storageKey) private var lcdRaw = LcdMode.dark.rawValue
    private var lcd: LcdMode { LcdMode(rawValue: lcdRaw) ?? .dark }

    private let db = WineDatabase.shared

    public init(onOpen: @escaping (WineEntry) -> Void) {
        self.onOpen = onOpen
    }

    // MARK: Steps

    private enum Step: Hashable {
        case color
        case body
        case origin
        /// The globe itself, reached from the origin question.
        case globe
        case country(Continent)
        case flavors
        /// A filtered flavour list, opened from a class or subclass tile.
        case flavorList(kind: FlavorKind, value: String)
        case reveal
    }

    private enum FlavorKind: Hashable {
        case classification
        case subclass
    }

    /// Which of the five questions a step belongs to. The globe, the country
    /// list and the flavour list are continuations of their question rather
    /// than questions of their own, so they do not advance the counter.
    private var questionNumber: Int {
        switch step {
        case .color: 1
        case .body: 2
        case .origin, .globe, .country: 3
        case .flavors, .flavorList: 4
        case .reveal: 5
        }
    }

    private func back() {
        Haptics.select()
        withAnimation(.easeOut(duration: 0.2)) {
            switch step {
            case .color: break
            case .body: step = .color
            case .origin: step = .body
            case .globe: step = .origin
            case .country: step = .globe
            case .flavors: step = .origin
            case .flavorList: step = .flavors
            case .reveal: step = .flavors
            }
        }
    }

    private func advance(to next: Step) {
        withAnimation(.easeOut(duration: 0.2)) { step = next }
    }

    // MARK: Body

    public var body: some View {
        ZStack {
            DexScreenBackground()

            switch step {
            case .globe:
                // Full-bleed: the globe needs the height, and a scroll view
                // around a drag-to-spin surface fights the gesture.
                VStack(spacing: 0) {
                    header
                    globeStep
                }
            default:
                VStack(spacing: 0) {
                    header
                    // Centred and cushioned rather than pinned to the top-left.
                    // Each step is two lines of prompt and a handful of controls
                    // — a third of a screen of content sitting in the top corner
                    // of an otherwise empty LCD, which read as a form rather
                    // than as a game.
                    //
                    // `GeometryReader` rather than `onGeometryChange(for:)`:
                    // that one is iOS 18 and the deployment target is 17, where
                    // it compiles against the SDK and is simply unavailable at
                    // runtime. The reader gives the scroll view's own height, so
                    // `minHeight` centres short steps in the visible area while
                    // long ones (the flavour lists) still scroll from the top.
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
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if step != .color {
                Button {
                    back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(lcd.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(DexPressStyle(scale: 0.9))
            }

            Text(step == .reveal ? "RESULT" : "STEP \(questionNumber) OF 5")
                .font(DexFont.retro(12))
                .tracking(1)
                .foregroundStyle(lcd.subtext)

            Spacer(minLength: 0)

            if !criteria.isEmpty {
                Button {
                    Haptics.select()
                    withAnimation(.easeOut(duration: 0.2)) {
                        criteria = GrapeScanCriteria()
                        step = .color
                    }
                } label: {
                    Text("RESET")
                        .font(DexFont.retro(12))
                        .tracking(1)
                        .foregroundStyle(lcd.subtext)
                }
                .buttonStyle(DexPressStyle(scale: 0.94))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .color: colorStep
        case .body: bodyStep
        case .origin: originStep
        case .globe: EmptyView()   // handled full-bleed above
        case .country(let continent): countryStep(continent)
        case .flavors: flavorStep
        case .flavorList(let kind, let value): flavorListStep(kind: kind, value: value)
        case .reveal: revealStep
        }
    }

    // MARK: 1 — colour

    private var colorStep: some View {
        question("WHAT COLOR?", "Start with the easy one.") {
            HStack(spacing: 10) {
                ForEach([GrapeColor.red, .white], id: \.rawValue) { option in
                    chip(
                        label: option.rawValue.uppercased(),
                        chip: db.palette.colorTypeChips[option.rawValue.uppercased()],
                        selected: criteria.color == option,
                        fill: true
                    ) {
                        criteria.color = criteria.color == option ? nil : option
                        advance(to: .body)
                    }
                }
            }
            skip("NOT SURE") { advance(to: .body) }
        }
    }

    // MARK: 2 — body

    private var bodyStep: some View {
        question("HOW IS THE BODY?", "How much of it is there, from a wisp to a mouthful.") {
            HStack(spacing: 8) {
                ForEach(GrapeBody.allCases) { option in
                    chip(
                        label: option.label,
                        chip: bodyChip(option),
                        selected: criteria.body == option,
                        fill: true
                    ) {
                        criteria.body = criteria.body == option ? nil : option
                        advance(to: .origin)
                    }
                }
            }
            skip("NOT SURE") { advance(to: .origin) }
        }
    }

    /// Body has no palette table of its own, so it borrows the wine-type chips'
    /// vocabulary: the same three weights, graded light to full.
    private func bodyChip(_ body: GrapeBody) -> Palette.Chip {
        switch body {
        case .light: Palette.Chip(bg: "#1a2e05", border: "#65a30d", text: "#d9f99d")
        case .medium: Palette.Chip(bg: "#451a03", border: "#d97706", text: "#fde68a")
        case .full: Palette.Chip(bg: "#3b0f0f", border: "#8b0000", text: "#fecdd3")
        }
    }

    // MARK: 3 — origin

    private var originStep: some View {
        question("DO YOU KNOW WHERE IT'S FROM?", "Open the globe and walk it down, or say so and move on.") {
            VStack(spacing: 10) {
                if let country = criteria.country {
                    HStack(spacing: 10) {
                        FlagSwatch(country: country, width: 52, height: 34)
                        Text(country.uppercased())
                            .font(DexFont.retro(12))
                            .foregroundStyle(lcd.text)
                        Spacer(minLength: 0)
                        Button {
                            Haptics.select()
                            criteria.country = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(lcd.subtext)
                        }
                        .buttonStyle(DexPressStyle(scale: 0.9))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.accent, lineWidth: 2)
                    )
                }

                bigButton(
                    criteria.country == nil ? "OPEN GLOBE SCAN" : "PICK ANOTHER",
                    symbol: "globe.americas.fill",
                    tint: Dex.green
                ) {
                    advance(to: .globe)
                }

                bigButton("I DON'T KNOW", symbol: "questionmark", tint: lcd.subtext) {
                    criteria.country = nil
                    advance(to: .flavors)
                }

                if criteria.country != nil {
                    bigButton("NEXT", symbol: "arrow.right", tint: Dex.yellow) {
                        advance(to: .flavors)
                    }
                }
            }
        }
    }

    private var globeStep: some View {
        // The real globe screen, not a copy of it: "open globe scan" should
        // open the globe scan. `showsSearch` is off because world search is a
        // route push, and pushing out of the scanner would discard the answers
        // collected so far.
        RetroGlobeScreen(
            onSelectContinent: { continent in
                advance(to: .country(continent))
            },
            onWorldSearch: {},
            showsSearch: false
        )
    }

    private func countryStep(_ continent: Continent) -> some View {
        let countries = db.countries(in: continent)

        return question(
            continent.markerLabel.replacingOccurrences(of: "\n", with: " "),
            "Which one?"
        ) {
            if countries.isEmpty {
                emptyNote("No countries listed for this continent.")
            } else {
                VStack(spacing: 8) {
                    ForEach(countries, id: \.self) { country in
                        Button {
                            Haptics.select()
                            criteria.country = country
                            advance(to: .flavors)
                        } label: {
                            HStack(spacing: 12) {
                                FlagSwatch(country: country, width: 64, height: 42)
                                Text(country.uppercased())
                                    .font(DexFont.retro(14))
                                    .foregroundStyle(lcd.text)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(lcd.subtext)
                            }
                            .padding(8)
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
    }

    // MARK: 4 — flavours

    private var basket: [WineEntry] {
        criteria.flavorIDs.compactMap { db.entry(id: $0) }
    }

    private var flavorStep: some View {
        question(
            "AROMAS AND FLAVORS?",
            "Pick a family to browse. Up to \(GrapeScanCriteria.flavorLimit) go in the basket — fewer is fine, none is fine."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                basketView

                group("CLASSES", values: db.flavorClasses, kind: .classification)
                group("SUBCLASSES", values: db.flavorSubclasses, kind: .subclass)

                bigButton(
                    basket.isEmpty ? "CONTINUE WITHOUT FLAVORS" : "SCAN",
                    symbol: "sparkle.magnifyingglass",
                    tint: Dex.yellow
                ) {
                    advance(to: .reveal)
                }
            }
        }
    }

    private func group(_ title: String, values: [String], kind: FlavorKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DexFont.retro(12))
                .tracking(1)
                .foregroundStyle(lcd.accent)

            FlowLayout(spacing: 6) {
                ForEach(values, id: \.self) { value in
                    chip(
                        label: value,
                        chip: kind == .classification
                            ? db.palette.flavorClassChips[value]
                            : db.palette.flavorSubclassChips[value],
                        selected: false,
                        fill: false
                    ) {
                        advance(to: .flavorList(kind: kind, value: value))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var basketView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "basket.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(lcd.accent)
                Text("BASKET \(basket.count)/\(GrapeScanCriteria.flavorLimit)")
                    .font(DexFont.retro(10))
                    .tracking(1)
                    .foregroundStyle(lcd.text)
                Spacer(minLength: 0)
            }

            if basket.isEmpty {
                Text("Empty — that is a valid answer.")
                    .font(DexFont.mono(16))
                    .foregroundStyle(lcd.subtext)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(basket) { flavor in
                        Button {
                            Haptics.select()
                            criteria.toggleFlavor(flavor.id)
                        } label: {
                            HStack(spacing: 5) {
                                Text(flavor.name.uppercased())
                                    .font(DexFont.retro(10))
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Color(dexHex: flavorChip(flavor).text))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(dexHex: flavorChip(flavor).bg))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color(dexHex: flavorChip(flavor).border), lineWidth: 1)
                            )
                        }
                        .buttonStyle(DexPressStyle(scale: 0.94))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(lcd.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(lcd.surfaceEdge, lineWidth: 1)
        )
    }

    private func flavorChip(_ entry: WineEntry) -> Palette.Chip {
        guard case .flavor(let f) = entry else {
            return Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
        }
        return db.palette.flavorSubclassChips[f.details.subclass]
            ?? db.palette.flavorClassChips[f.details.classification]
            ?? Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
    }

    private func flavorListStep(kind: FlavorKind, value: String) -> some View {
        let matches = kind == .classification
            ? db.flavors(inClass: value)
            : db.flavors(subclass: value)

        return question(
            value.replacingOccurrences(of: "_", with: " "),
            criteria.flavorsAreFull
                ? "Basket is full — remove one to swap it out."
                : "Tap what you can taste."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                basketView

                if matches.isEmpty {
                    emptyNote("Nothing filed under this one.")
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(matches) { flavor in
                            let chosen = criteria.flavorIDs.contains(flavor.id)
                            chip(
                                label: flavor.name,
                                chip: flavorChip(flavor),
                                selected: chosen,
                                fill: chosen
                            ) {
                                // The cap is enforced in `toggleFlavor`, so a
                                // tap past the limit is a no-op rather than a
                                // silent replacement of someone's first pick.
                                criteria.toggleFlavor(flavor.id)
                            }
                        }
                    }
                }

                bigButton("DONE", symbol: "checkmark", tint: Dex.green) {
                    advance(to: .flavors)
                }
            }
        }
    }

    // MARK: 5 — reveal

    private var revealStep: some View {
        let matches = db.grapesMatching(criteria)

        return VStack(alignment: .leading, spacing: 16) {
            criteriaSummary

            if let best = matches.first {
                reveal(best, others: Array(matches.dropFirst().prefix(6)), total: matches.count)
            } else {
                notFound
            }

            bigButton("SCAN AGAIN", symbol: "arrow.counterclockwise", tint: lcd.subtext) {
                Haptics.select()
                withAnimation(.easeOut(duration: 0.2)) {
                    criteria = GrapeScanCriteria()
                    step = .color
                }
            }
        }
    }

    private var criteriaSummary: some View {
        FlowLayout(spacing: 6) {
            if let color = criteria.color {
                summaryChip(color.rawValue.uppercased(), db.palette.colorTypeChips[color.rawValue.uppercased()])
            }
            if let body = criteria.body {
                summaryChip(body.label, bodyChip(body))
            }
            if let country = criteria.country {
                summaryChip(country.uppercased(), db.palette.chip(country: country))
            }
            ForEach(basket) { flavor in
                summaryChip(flavor.name.uppercased(), flavorChip(flavor))
            }
            if criteria.isEmpty {
                summaryChip("NO CRITERIA", nil)
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

    private func reveal(_ grape: WineEntry, others: [WineEntry], total: Int) -> some View {
        VStack(spacing: 14) {
            Text(total == 1 ? "IT'S PROBABLY" : "BEST MATCH")
                .font(DexFont.retro(14))
                .tracking(2)
                .foregroundStyle(Dex.yellow)

            EntryIconWell(entry: grape, size: 150, cornerRadius: 18)

            Text(grape.name.uppercased())
                .font(DexFont.retro(22))
                .foregroundStyle(lcd.text)
                .shadow(color: lcd.accent.opacity(0.55), radius: 0, x: 3, y: 3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(grape.entryDescription)
                .font(DexFont.mono(21))
                .foregroundStyle(lcd.bodyText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.tap()
                onOpen(grape)
            } label: {
                Text("OPEN ENTRY")
                    .font(DexFont.retro(15))
                    .tracking(2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 18)
                    .background(Capsule().fill(Dex.green))
            }
            .buttonStyle(DexPressStyle(scale: 0.96))

            if !others.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ALSO FITS (\(total - 1) MORE)")
                        .font(DexFont.retro(12))
                        .tracking(1)
                        .foregroundStyle(lcd.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(others) { other in
                        Button {
                            Haptics.select()
                            onOpen(other)
                        } label: {
                            HStack(spacing: 10) {
                                EntryIconWell(entry: other, size: 44, cornerRadius: 8)
                                Text(other.name.uppercased())
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
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(lcd.accent.opacity(0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(lcd.accent.opacity(0.45), lineWidth: 2)
        )
    }

    private var notFound: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Dex.amber400)

            Text("GRAPE NOT FOUND")
                .font(DexFont.retro(19))
                .tracking(1)
                .foregroundStyle(Dex.amber400)
                .multilineTextAlignment(.center)

            Text("You're drinking rare grapes!")
                .font(DexFont.mono(24))
                .foregroundStyle(lcd.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Nothing in the database fits all of that. Loosen a criterion and scan again — or accept the compliment.")
                .font(DexFont.mono(16))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(Dex.amber400.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(Dex.amber400.opacity(0.5), lineWidth: 2)
        )
    }

    // MARK: Shared chrome

    /// The prompt and its controls, centred.
    ///
    /// Deliberately centre-aligned where the rest of the app is left-aligned:
    /// the scanner is one question at a time on an otherwise empty screen, not
    /// a list, and a lone left-aligned question in the top corner looked like
    /// the screen had failed to finish loading.
    private func question<C: View>(
        _ title: String,
        _ subtitle: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(spacing: 18) {
            Text(title)
                .font(DexFont.retro(20))
                .tracking(1)
                .foregroundStyle(lcd.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(DexFont.mono(22))
                .foregroundStyle(lcd.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            content()
        }
        .frame(maxWidth: .infinity)
    }

    /// A selectable chip in the palette's own colours.
    ///
    /// `fill` distinguishes a *choice* from a *doorway*: answers paint
    /// themselves in when picked, while the class and subclass tiles stay
    /// outlined because tapping them opens a list rather than answering
    /// anything.
    private func chip(
        label: String,
        chip: Palette.Chip?,
        selected: Bool,
        fill: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let resolved = chip ?? Palette.Chip(bg: "#1c1917", border: "#57534e", text: "#e7e5e4")
        let border = Color(dexHex: resolved.border)

        return Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 6) {
                Text(EntryDisplay.hyphenated(label.replacingOccurrences(of: "_", with: " ").uppercased()))
                    .font(DexFont.retro(14))
                    .multilineTextAlignment(.center)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundStyle(Color(dexHex: resolved.text))
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: fill ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(dexHex: resolved.bg).opacity(selected ? 1 : 0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(border, lineWidth: selected ? 3 : 1)
            )
        }
        .buttonStyle(DexPressStyle(scale: 0.96))
    }

    private func bigButton(
        _ label: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .bold))
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

    /// Skipping is a real answer, so it gets a real control rather than being
    /// something you discover by pressing Next with nothing chosen.
    private func skip(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(label)
                .font(DexFont.retro(13))
                .tracking(1)
                .foregroundStyle(lcd.subtext)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DexPressStyle(scale: 0.97))
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(DexFont.mono(21))
            .foregroundStyle(lcd.subtext)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
#endif
