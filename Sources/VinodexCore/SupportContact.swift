import Foundation

/// **Where to write, and what the message arrives titled** (0.8.91, F1).
///
/// In Core rather than in `SupportScreen` for the reason every other string this
/// app puts in front of a user is: `VinodexUI` has no test target, and an
/// address that is subtly wrong — a typo, a stray space, a percent-encoding that
/// turns the subject into part of the recipient — is a bug that fails silently
/// into somebody else's inbox. `SupportContactTests` is what makes that a check.
///
/// **The address is a placeholder and is marked as one.** §F1 says
/// "temporary placeholder address" in as many words. It is a `let` here and
/// nowhere else, so replacing it is one edit rather than a grep.
public enum SupportContact: Sendable {
    /// The recipient. Temporary — see the type note.
    public static let address = "hello@vinodex.com"

    /// The one paragraph the screen shows.
    ///
    /// Says what will and will not help, because a support page that only says
    /// "get in touch" collects messages nobody can act on. It does not promise a
    /// response time, which is the other thing these pages do and cannot keep.
    public static let blurb = """
    Found something broken, or thought of something the device should do? \
    Write in. Say which screen you were on and what you expected -- that is \
    usually the whole bug report. The firmware version travels with the \
    message.
    """

    /// The subject line, carrying the installed firmware.
    ///
    /// The first question anyone answering this mail has to ask is which build
    /// it came from, and `AppVersion.display` is the one place that knows. A
    /// version the user has to be asked for is a version half of them get wrong.
    public static func subject(version: String) -> String {
        "Vinodex " + version
    }

    /// The `mailto:` URL, for the arm that hands the message to whatever app the
    /// user actually reads mail in.
    ///
    /// Percent-encoded through `URLComponents` rather than by hand: a subject
    /// with a space in it is the common case, and a raw space makes
    /// `URL(string:)` return nil — which would have degraded a working mail
    /// client to the "no mail app" alert.
    public static func mailtoURL(version: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [URLQueryItem(name: "subject", value: subject(version: version))]
        return components.url
    }
}
