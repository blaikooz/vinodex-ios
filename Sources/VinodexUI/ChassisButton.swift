#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import VinodexCore

// The chassis's two physical controls, split out of DeviceChassis.swift
// (AUDIT **M30**) — that file had eleven top-level types in 1,220 lines.
// Nothing here changed in the move.

// MARK: - Chassis buttons

/// The physical-looking Back and Home buttons.
///
/// Haptics fire here rather than at call sites so every chassis button feels the
/// same — the main thing a native build can offer that the web app cannot.
struct ChassisButton: View {
    /// `bookmarks` replaces Back on the main screen, where there is nowhere
    /// to go back to and the button was just a greyed-out slot.
    enum Kind { case back, home, bookmarks }

    let kind: Kind
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
    @AppStorage(ChassisSkin.storageKey) private var skinRaw = ChassisSkin.classic.rawValue

    private var skin: ChassisSkin { ChassisSkin(rawValue: skinRaw) ?? .classic }

    init(kind: Kind, enabled: Bool = true, action: @escaping () -> Void) {
        self.kind = kind
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack {
                Circle().fill(gradient)
                Circle().strokeBorder(borderColor, lineWidth: 3)
                icon
            }
            .frame(width: DexMetrics.footerControl, height: DexMetrics.footerControl)
            .shadow(color: .black.opacity(0.6), radius: 6, y: 8)
        }
        .buttonStyle(DexPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(accessibilityLabel)
    }

    /// VoiceOver reads the SF Symbol otherwise — Saved announces as "person",
    /// and Back/Home are unlabeled. (audit H10)
    private var accessibilityLabel: String {
        switch kind {
        case .back: "Back"
        case .home: "Home"
        case .bookmarks: "Saved entries"
        }
    }

    private var gradient: LinearGradient {
        switch kind {
        case .back, .bookmarks:
            LinearGradient(colors: [skin.control.top, skin.control.bottom], startPoint: .top, endPoint: .bottom)
        case .home:
            LinearGradient(colors: [skin.accent.light, skin.accent.mid], startPoint: .top, endPoint: .bottom)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .back, .bookmarks: skin.control.edge
        case .home: skin.accent.edge
        }
    }

    // Glyphs scale with `footerControl` rather than carrying fixed points, so
    // enlarging the buttons does not leave the same small icon floating in a
    // bigger circle.
    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .back:
            Image(systemName: "chevron.left")
                .font(.system(size: DexMetrics.footerControl * 0.47, weight: .heavy))
                .foregroundStyle(skin.control.glyph)
        case .bookmarks:
            Image(systemName: "person.crop.circle")
                .font(.system(size: DexMetrics.footerControl * 0.44, weight: .semibold))
                .foregroundStyle(skin.control.glyph)
        case .home:
            Circle()
                .fill(LinearGradient(colors: [skin.accent.pale, skin.accent.bright], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(skin.accent.mid, lineWidth: 1))
                .padding(2)
                .overlay {
                    Image(systemName: "house.fill")
                        .font(.system(size: DexMetrics.footerControl * 0.41, weight: .bold))
                        .foregroundStyle(skin.accent.ink)
                }
        }
    }
}

/// Chunky press feedback mirroring the web app's `active:scale` / `active:translate-y`.
struct DexPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    init(scale: CGFloat = 0.96) { self.scale = scale }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
#endif
