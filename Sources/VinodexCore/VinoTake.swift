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
        "S015": "White grapes treated like reds - the oldest technique currently being called a trend. Amber glass, tea tannin, strong opinions included.",
    ]

    /// The floor. Nil only for continents.
    public static func compose(for entry: WineEntry) -> String? {
        if let authored = overrides[entry.id] { return authored }
        switch entry {
        case .grape(let g):
            return grapeTake(g)
        case .region(let r):
            return regionTake(r)
        case .style(let s):
            return styleTake(s)
        case .flavor:
            return "Find it in the glass before you read it on the card. Every note you can name is one you will find again."
        case .continent:
            return nil
        }
    }

    // MARK: The axes

    private static func grapeTake(_ g: GrapeEntry) -> String {
        let c = g.grapeCharacteristics
        let origin = g.details.origin
        // **Dominant axis, not threshold order** (checkpoint V3's first
        // finding): fixed thresholds put the whole catalog in two buckets —
        // 77 grapes "struck bell", 97 "big tannin", three templates
        // unreachable. The authored bars skew high, so what distinguishes a
        // grape is which bar leads, and a near-flat profile is its own
        // personality. Spread on live data: ~31 tannin, ~110 acid (split by
        // body), ~21 balanced, ~15 aromatic.
        let axes: [(String, Double)] = [
            ("tannin", c.tannin), ("acid", c.acid), ("aromatics", c.aromatics),
        ]
        let spread = (axes.map(\.1).max() ?? 0) - (axes.map(\.1).min() ?? 0)
        if spread < 0.15 {
            return "No loud edges - tannin, acid and perfume in step. Balance reads as boring until you taste it done right."
        }
        switch axes.max(by: { $0.1 < $1.1 })?.0 {
        case "tannin":
            return "Tannin leads here. Decant it, feed it something that pushes back, and do not rush what \(origin) built to last."
        case "aromatics":
            return "The perfume does half the work before you sip. Serve it cool and let the glass introduce itself."
        default:
            if c.body <= 0.45 {
                return "Acid up front, nothing to hide behind. Cold bottle, bright glass - \(origin)'s idea of refreshment."
            }
            return "Acidity like a struck bell, with the frame to carry it. It cuts through anything the kitchen sends out."
        }
    }

    private static func regionTake(_ r: RegionEntry) -> String {
        let climateWord = (r.climate?.rawValue ?? "patient").lowercased()
        let grape = r.details.notableGrapes.first
        if let soil = r.details.soilType?.split(separator: ",").first.map(String.init) {
            let dirt = soil.lowercased()
            if let grape {
                return "\(dirt.prefix(1).capitalized + dirt.dropFirst()) under a \(climateWord) sky, and \(grape) knows it. The dirt writes the first draft here."
            }
            return "\(dirt.prefix(1).capitalized + dirt.dropFirst()) under a \(climateWord) sky. The dirt writes the first draft; the cellar edits."
        }
        if let grape {
            return "A \(climateWord) climate and \(grape) with opinions. The place argues; the wine usually wins."
        }
        return "A \(climateWord) climate with history in the hedgerows. Places like this taught the grapes everything."
    }

    private static func styleTake(_ s: StyleEntry) -> String {
        switch s.details.classification {
        case "METHOD":
            return "A method, not a place. Learn how it is made and you will spot it blind for the rest of your life."
        case "BLEND":
            return "A committee that works: each grape covers another's weaknesses. Rare in wine. Rarer in committees."
        case "ORIGIN":
            return "Named for where it comes from, and the name is doing legal work. The place is the recipe."
        default:
            let body = (s.details.body ?? "").lowercased()
            if body.contains("full") {
                return "The heavyweight shelf. Pour it with food that pushes back, and give the glass room to breathe."
            }
            if body.contains("light") {
                return "Easy company. Chill it, pour it, repeat - not every bottle needs a thesis."
            }
            return "A way of making wine, not a place it is from. Once you can taste the intent, labels get easier."
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
            guard let take = compose(for: entry) else {
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
        }
        return out
    }
}
