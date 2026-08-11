import Foundation
import Testing
@testable import VinodexCore

/// The share line and the web address (0.8.94, D1) — held still here because
/// both are policy: the words the spec dictates, and a URL shape that must
/// not drift once links are in people's chat histories.
struct VinodexWebTests {
    @Test("the share line reads exactly as the spec words it")
    func shareLine() {
        #expect(
            VinodexWeb.shareText(entryName: "Nebbiolo")
                == "Check this Nebbiolo out on Vinodex"
        )
    }

    @Test("entry URLs are id-keyed on the deployed host")
    func entryURL() throws {
        let url = try #require(VinodexWeb.entryURL(id: "G001"))
        #expect(url.absoluteString == "https://vinodex.vercel.app/entry/G001")
    }

    @Test("every catalog id survives the URL builder")
    func allIdsBuild() {
        for entry in WineDatabase.shared.entries {
            let url = VinodexWeb.entryURL(id: entry.id)
            #expect(url != nil, "\(entry.id) built no URL")
            #expect(
                url?.absoluteString.hasPrefix(VinodexWeb.base) == true,
                "\(entry.id) escaped off the host"
            )
        }
    }
}
