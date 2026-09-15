#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import VinodexCore

/// **CREDITS** (0.9.59, maintainer order): every third-party thing the bundle
/// carries, with its licence, on one page behind the SETTINGS panel's
/// CREDITS button.
///
/// The three-line credit lived at the foot of the FIRMWARE screen from 0.9.46,
/// which was fine while there were two things to credit. There are seven
/// groups now — and two of them are *conditions*, not courtesies: CC BY 4.0 on
/// the wine index and CC BY 3.0 on the game-icons glyphs both require the
/// licensor named, the licence named, and modifications stated. This page is
/// where that is satisfied in-app; `NOTICE.md` and `ATTRIBUTION.md` in the
/// repo are the long form and this follows them line for line. **Change them
/// together.**
public struct CreditsScreen: View {
    var settings: AppSettings = .shared
    private var lcd: LcdMode { settings.lcdMode }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                intro

                section("PIXEL FLAGS", [
                    ("R74n", "The pixel flag art is the R74n collective's PixelFlags (r74n.com/pixelflags), used with the creators' permission of 7 September 2026 under the R74n Content License v1.1. Thirty-four of the thirty-five bundled flags are theirs; the VARIOUS pennant is first-party."),
                ])

                section("WINE INDEX", [
                    ("LWIN, by Liv-ex", "The label reader's offline bottle index is a subset of the Liv-ex Wine Identification Number database (liv-ex.com/lwin), licensed Creative Commons Attribution 4.0 International. MODIFIED: only live Wine and Fortified Wine rows are kept, 184,968 of 211,786, with the LWIN-7, display name, country, region, colour and category re-encoded into this app's packed format. No row's meaning was changed."),
                ])

                section("MAP DATA", [
                    ("Natural Earth", "The globe and every region map are rendered from Natural Earth's 1:10m admin-0 and admin-1 boundaries. Public domain. Two deliberate departures from the source are recorded in the repository: Crimea is drawn as Ukraine, and the Israeli-administered Golan is cut from HaZafon as its own area."),
                    ("Statistik Austria", "The Wachau's boundary is the eight Gemeinden that Weingesetz 2009 §21(3) names, from Statistik Austria's Gemeinden geometry, CC BY 4.0. Datenquelle: Statistik Austria — data.statistik.gv.at."),
                    ("Etalab", "Sauternes and Châteauneuf-du-Pape are drawn from French commune boundaries published under the Licence Ouverte / Open Licence (Etalab)."),
                ])

                section("FONTS", [
                    ("Press Start 2P", "Copyright 2012 The Press Start 2P Project Authors, with Reserved Font Name Press Start 2P. SIL Open Font License 1.1. Unmodified."),
                    ("VT323", "Copyright 2011 The VT323 Project Authors. SIL Open Font License 1.1. Unmodified."),
                ])

                section("ICON GLYPHS", [
                    ("game-icons.net, CC BY 3.0", "Fifty-five glyphs by the game-icons.net artists, recoloured to this app's palette and rasterised — no shape edits. Delapouite (delapouite.com): almond, apple-core, banana, banana-bunch, beehive, bell-pepper, butter, cherry, coffee-cup, cut-lemon, gas-pump, herbs-bundle, high-grass, honey-jar, jelly, jelly-beans, mushrooms, mussel, olive, peach, pear, pineapple, plum, raspberry, smoking-pipe, stone-pile, strawberry, teapot-leaves, tomato, weight-lifting-up, weight-scale. Lorc (lorcblog.blogspot.com): blackcurrant, elderberry, fluffy-cloud, honeycomb, hot-spices, leather-vest, lotus-flower, pine-tree, rose, salt-shaker, shiny-apple, sliced-bread, teapot, vanilla-flower, volcano, wine-glass. Caro Asercion: bok-choy, deer, mason-jar. sbed: death-skull. Lorc and sbed: clover. Lorc or John Redman: rock. Rihlsul: chocolate-bar. Willdabeast (wjbstories.blogspot.com): gold-bar."),
                    ("Lucide, ISC", "Twelve glyphs — circle, cloud, droplet, flame, flower-2, gem, leaf, mountain, shield, sparkles, sun, triangle — copyright Lucide Icons and Contributors, ISC License. circle and triangle derive from Feather (MIT, copyright 2013–present Cole Bemis)."),
                    ("Material Design Icons, Apache 2.0", "One glyph, help-circle-outline, from the Pictogrammers collection under the Apache License 2.0 and the Pictogrammers Free License."),
                ])

                section("EVERYTHING ELSE", [
                    ("First-party", "The drawn art, the chassis, the grape and style portraits, the sound effects, the world texture and the wine encyclopedia itself are Vinodex's own work, all rights reserved. The full inventory is NOTICE.md in the repository."),
                ])
            }
            .padding(18)
        }
        .background(lcd.page)
    }

    private var intro: some View {
        Text("What Vinodex carries that is not its own, and the terms it carries it under. Two of these are obligations rather than thanks: the wine index and the game-icons glyphs are licensed on the condition that this page exists.")
            .font(DexFont.mono(17))
            .foregroundStyle(lcd.subtext)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func section(_ title: String, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DexFont.retro(12))
                .tracking(2)
                .foregroundStyle(lcd.accent)
            Rectangle().fill(lcd.accent.opacity(0.6)).frame(height: 2)
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0.uppercased())
                        .font(DexFont.retro(10))
                        .tracking(1)
                        .foregroundStyle(lcd.text)
                    Text(row.1)
                        .font(DexFont.mono(16))
                        .foregroundStyle(lcd.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
#endif
