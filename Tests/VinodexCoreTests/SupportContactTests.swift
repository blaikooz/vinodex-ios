import Testing
import Foundation
@testable import VinodexCore

/// **The contact screen's one fact** (0.8.91, F1).
///
/// The screen is a paragraph and a button and is invisible to `swift test`. What
/// is testable is the thing that can be silently wrong: an address that does not
/// parse, or a subject whose spaces break the URL the fallback arm opens — which
/// would turn a working mail client into the "no mail app" alert.
@Suite("Support contact")
struct SupportContactTests {
    @Test("the address is a plausible mailbox")
    func addressParses() {
        let address = SupportContact.address
        #expect(address.contains("@"))
        #expect(!address.contains(" "))
        #expect(address == address.trimmingCharacters(in: .whitespacesAndNewlines))
        let parts = address.split(separator: "@")
        #expect(parts.count == 2)
        #expect(parts.last?.contains(".") == true)
        #expect(address.allSatisfy { $0.isASCII })
    }

    /// The blurb is shown in the retro/mono faces, which carry a partial
    /// Latin-1 range — the same assertion `VinoDialogue.problems()` makes about
    /// every line he says, for the same reason.
    @Test("the copy is printable ASCII and says something")
    func blurbIsPrintable() {
        #expect(!SupportContact.blurb.isEmpty)
        #expect(SupportContact.blurb.allSatisfy { $0.isASCII })
        #expect(SupportContact.blurb.count < 400, "a brief contact screen, per the item")
    }

    @Test("the subject carries the version")
    func subjectCarriesTheVersion() {
        #expect(SupportContact.subject(version: "0.8.91").contains("0.8.91"))
        #expect(SupportContact.subject(version: AppVersion.display).contains(AppVersion.display))
    }

    /// A space in the subject is the common case and is exactly what makes a
    /// hand-built `mailto:` string fail to parse. Both are asserted because the
    /// nil is the failure the screen cannot distinguish from "no mail client".
    @Test("the mailto URL survives a subject with spaces")
    func mailtoEncodes() {
        let url = SupportContact.mailtoURL(version: "0.8.91 (test build)")
        #expect(url != nil)
        guard let url else { return }
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString.contains(SupportContact.address))
        #expect(!url.absoluteString.contains(" "), "a raw space makes this URL unopenable")
        #expect(url.absoluteString.contains("subject="))
        // And the real one, which is what actually ships.
        #expect(SupportContact.mailtoURL(version: AppVersion.display) != nil)
    }
}
