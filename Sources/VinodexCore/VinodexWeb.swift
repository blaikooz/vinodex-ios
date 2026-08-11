import Foundation

/// The web app's address, and the share strings built against it (0.8.94, D1).
///
/// **In Core, because both halves are policy rather than presentation.** The
/// share sheet is UI; *what* an entry share says and *where* it points are
/// facts a Linux test can hold still — the same split `SupportContact` made
/// for the mail button in 0.8.91.
///
/// **The URL shape is `/entry/<id>`, minted here first.** The web app has no
/// deep-link routing yet — nothing in `vinodex-web` reads a pathname — but
/// its Vercel config rewrites every non-asset path to the SPA, so this link
/// opens the app today (at its home screen) and starts resolving to the entry
/// the day the web side learns the route. Ids rather than names, because ids
/// are the persisted identity: a rename batch must not break every link
/// already sent.
public enum VinodexWeb {
    /// The deployment the README calls "Open the app".
    public static let base = "https://vinodex.vercel.app"

    /// The entry's page on the web app.
    public static func entryURL(id: String) -> URL? {
        // Ids are ASCII (G001, R042…) today; escaped anyway, because a URL
        // builder that trusts its input is the next batch's bug report.
        guard let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: base + "/entry/" + escaped)
    }

    /// The prefilled share line (0.8.94, D1), exactly as the spec words it.
    public static func shareText(entryName: String) -> String {
        "Check this \(entryName) out on Vinodex"
    }
}
