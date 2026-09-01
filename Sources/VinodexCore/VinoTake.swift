import Foundation

/// **Vinobot's take on an entry** (rework V3, 2026-09-01).
///
/// One line per entry, in his voice: a template floor composed from fields
/// the catalog genuinely carries, with an authored-override ceiling for the
/// flagship pages. The spec's V3 checkpoint is explicit that the floor is
/// the risky half — if the composed lines read robotic on the device, the
/// templates get rewritten before the ceiling grows — so the composition is
/// deliberately axis-led: each template speaks to the entry's most
/// distinctive measured trait, never a generic compliment.
///
/// ## Honesty is the whole design
///
/// Every clause traces to a field: tannin and acid to the authored
/// characteristics bars, body to the body class, the closing beat to the
/// origin. Nothing asserts a fact the row cannot back — the same rule the
/// GODFORSAKEN bubble learned in 0.8.9c. Continents get no take; a
/// continent is a table of contents, not a wine.
///
/// Rules ride the scene discipline: <= 34 words, printable ASCII, and the
/// take never repeats the entry's own name for grapes/regions/styles (the
/// page's hero already says it; his line sits beneath). `problems(in:)`
/// runs the whole catalog through the gates in `VinoTakeTests`.
public enum VinoTake {
    /// The authored ceiling. Keys are entry ids — load-bearing spellings,
    /// pinned by the tests to resolve — and the count is stated in the
    /// tests' title so a silent addition cannot slip in.
    public static let overrides: [String: String] = [
        // The king. His take concedes the obvious with a straight face.
        "G001": "The world planted it everywhere and it behaved everywhere. Structure, cassis, and a pension plan. Start here, then wander.",
        // Pinot: the heartbreak grape, played dry.
        "G002": "Thin skin, strong opinions. When it works there is nothing better; when it does not, nobody admits how often.",
        // Riesling: the sommelier handshake.
        "G007": "Sugar takes the blame, acid does the work. The driest ones will outlive us both. Trust the label's fine print.",
        // Bordeaux: the reference point.
        "R001": "The reference everyone measures against, including the people pretending not to. Left bank firm, right bank soft. Pick a bank.",
        // Burgundy: the map is the point.
        "R002": "One grape, a thousand fences, and centuries of arguing about which side of the fence tastes better. The arguing is the point.",
        // Champagne: the law and the chalk.
        "R003": "Chalk, cold, and a second fermentation under law. Everything else calling itself this is borrowing the name without the paperwork.",
        // Napa: the new world's proof.
        "R013": "Proof the new world could go toe to toe, and priced like it knows. The valley floor is sunshine with a mortgage.",
        // Orange wine: the oldest new thing.
        "S015": "White grapes treated like reds. The oldest technique in the book, currently being called a trend. Amber glass, tea tannin, strong opinions included.",
    ]

    /// The floor. Nil only for continents. Takes the database because a
    /// pokedex entry cites the pokedex: a flavour's take counts the grapes
    /// that log it, and inventing that number would break the honesty rule.
    public static func compose(for entry: WineEntry, in db: WineDatabase) -> String? {
        if let authored = overrides[entry.id] { return authored }
        switch entry {
        case .grape(let g):
            return grapeTake(g)
        case .region(let r):
            return regionTake(r)
        case .style(let s):
            return styleTake(s)
        case .flavor:
            let count = db.entries(in: .grapes).filter { grape in
                guard case .grape(let g) = grape else { return false }
                return g.tastingProfile?.contains { $0.note == entry.name } ?? false
            }.count
            if count > 0 {
                return "Logged in \(count) \(count == 1 ? "grape" : "grapes") across the catalog. Name it blind three times and it is yours for life."
            }
            return "Rare in the wild. No grape in the catalog leads with it. Consider it a collector's note."
        case .continent:
            return nil
        }
    }

    // MARK: The axes

    private static func grapeTake(_ g: GrapeEntry) -> String {
        let c = g.grapeCharacteristics
        let origin = g.details.origin
        // The pokedex register (checkpoint V3, round two): observed nature
        // first — this grape's own logged tasting notes — then one wry,
        // factual behaviour. "Robotic" was round one's serving advice;
        // an entry that names its own flavours cannot be mistaken for a
        // form letter.
        let notes = (g.tastingProfile ?? []).map(\.note)
        let n1 = notes.first?.lowercased()
        let n2 = notes.dropFirst().first?.lowercased()

        if g.rarity == .godforsaken, let n1 {
            return "Nearly extinct in the wild. A handful of rows keeps it going, and what survives tastes of \(n1) and stubbornness."
        }

        let axes: [(String, Double)] = [
            ("tannin", c.tannin), ("acid", c.acid), ("aromatics", c.aromatics),
        ]
        let spread = (axes.map(\.1).max() ?? 0) - (axes.map(\.1).min() ?? 0)
        if spread < 0.15 {
            if let n1, let n2 {
                return "Shows \(n1), \(n2), and no single loud voice. Balance reads as boring until somebody does it right."
            }
            return "No loud edges: tannin, acid and perfume in step. Balance reads as boring until you taste it done right."
        }
        switch axes.max(by: { $0.1 < $1.1 })?.0 {
        case "tannin":
            if let n1, let n2 {
                return "Leads with \(n1) and \(n2) from behind a wall of tannin. It guards its fruit the way \(origin) guards a recipe."
            }
            return "Tannin leads here. It guards its fruit the way \(origin) guards a recipe: firmly, and for years."
        case "aromatics":
            if let n1 {
                return "The \(n1) perfume arrives before the glass does. The vines are quieter than the wine."
            }
            return "The perfume arrives before the glass does. The vines are quieter than the wine."
        default:
            if c.body <= 0.45 {
                if let n1, let n2 {
                    return "Mostly \(n1), \(n2) and voltage. Built for cold bottles and hot afternoons."
                }
                return "Acid up front, nothing hiding behind it. Built for cold bottles and hot afternoons."
            }
            if let n1, let n2 {
                return "Carries \(n1) and \(n2) on a spine of acidity. It cuts through a rich meal like fresh string through clay."
            }
            return "Acidity with the frame to carry it. It cuts through a rich meal like fresh string through clay."
        }
    }

    private static func regionTake(_ r: RegionEntry) -> String {
        let climateWord = (r.climate?.rawValue ?? "patient").lowercased()
        let grape = r.details.notableGrapes.first
        if let soil = r.details.soilType?.split(separator: ",").first.map(String.init)?.lowercased(), let grape {
            return "Raises \(grape) on \(soil) under a \(climateWord) sky. The ground writes the first draft; the cellar only edits."
        }
        if let grape {
            return "A \(climateWord) home where \(grape) sets the house style. Maps explain the borders; the glass explains the map."
        }
        return "A \(climateWord) outpost with more history than hectares. Small places argue loudest in wine."
    }

    private static func styleTake(_ s: StyleEntry) -> String {
        switch s.details.classification {
        case "METHOD":
            return "Defined by how it is made, not where. Learn the method once and you will spot it blindfolded forever."
        case "BLEND":
            return "A committee that works: each grape covers another's weakness. Rare in wine. Rarer in committees."
        case "ORIGIN":
            return "Its name is a place doing legal work. Imitators can copy the grapes but never the paperwork."
        default:
            let body = (s.details.body ?? "").lowercased()
            if body.contains("full") {
                return "The heavyweight class. It trains against rich food and usually wins on points."
            }
            if body.contains("light") {
                return "Featherweight and proud of it. Serve it cold, drink it young, repeat as needed."
            }
            return "A way of making wine rather than a place. Taste the intent and labels stop being homework."
        }
    }

    // MARK: The gate

    /// Runs the whole catalog through the rules. Empty means clean.
    public static func problems(in db: WineDatabase) -> [String] {
        var out: [String] = []
        for (id, _) in overrides where db.entry(id: id) == nil {
            out.append("override \(id) names no entry")
        }
        for entry in db.entries {
            guard let take = compose(for: entry, in: db) else {
                if entry.category != .continents {
                    out.append("\(entry.id): no take composed")
                }
                continue
            }
            let words = take.split(separator: " ").count
            if words > 34 { out.append("\(entry.id): \(words) words, over the cap") }
            // The ASCII rule guards AUTHORED words — the take renders in the
            // body fonts, which draw diacritics fine, but his own vocabulary
            // stays ASCII like every Vino surface. Catalog-sourced words
            // (a grape called Semillon with its accent, a soil, an origin)
            // are the entry's spelling, not his, and are exempt: strip them
            // before the check.
            var residue = take
            var sourced: [String] = [entry.name]
            switch entry {
            case .grape(let g):
                sourced.append(g.details.origin)
            case .region(let r):
                sourced.append(contentsOf: r.details.notableGrapes)
                if let soil = r.details.soilType { sourced.append(soil) }
            default:
                break
            }
            for word in sourced {
                residue = residue.replacingOccurrences(of: word, with: "")
                residue = residue.replacingOccurrences(of: word.lowercased(), with: "")
            }
            if residue.contains(where: { !$0.isASCII }) { out.append("\(entry.id): non-ASCII in authored words") }
            // The dash construction is banned by maintainer ruling
            // (checkpoint V3, round three): a spaced hyphen reads as an em
            // dash in prose, and he speaks in sentences, colons and commas.
            if take.contains(" - ") { out.append("\(entry.id): dash construction in take") }
        }
        return out
    }
}
