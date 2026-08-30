// The tip jar, and the rules it lives by.
//
// A tip jar can be done badly in about six ways, and every one of them is a thing this app
// will not do: it will not appear on launch, it will not appear as a sheet over a match, it
// will not count what anybody has given, it will not hand out a badge or a "supporter" tier,
// and it will not ask twice. A gift that buys something is a purchase, and a purchase in a
// free app has to go through Apple.
//
// What is left is one quiet line at the bottom of a screen that is read between matches,
// saying what the app is and offering a way to say thanks. That is the whole design, and
// the reason it is written down here is that a tip jar drifts if nobody wrote down where
// the line was.
import Foundation

/// Where a thank-you goes, and what the page around it says.
public struct SupportLink: Equatable, Sendable {
    /// The page that takes it — Ko-fi, Buy Me a Coffee, or anything like them.
    ///
    /// Opened in the browser, never inside the app. Apple's rules leave exactly one lawful
    /// way to be paid outside their system, and this is it: a link out. A payment field of
    /// our own on this screen would be rejected, and rightly.
    public var url: URL

    public init?(_ address: String) {
        // A link that goes nowhere is worse than no link, so a page with nothing to point
        // at simply has no tip jar on it. Failing to build is how that is enforced.
        guard let url = URL(string: address), url.scheme == "https", url.host != nil else {
            return nil
        }
        self.url = url
    }

    /// The words on the button. A noun, not an imperative: nobody is being told to do this.
    public static let action = "Buy me a coffee"

    /// The one sentence of asking this app does.
    ///
    /// No "please", no figure suggested, no mention of what it costs to run — those are the
    /// sentences that turn a thank-you into a bill.
    public static let invitation =
        "If it saved you a clipboard, you can say thanks. Entirely optional, and nothing changes if you don't."
}

/// What the about page says about the app itself.
///
/// Plain facts, in the order somebody would ask them. It doubles as the honest answer to
/// "what does this app do with my data", which is a question worth being able to answer in
/// one screen rather than a privacy policy nobody opens.
public enum About {
    public static let tagline = "Serve-by-serve tracking for a volleyball season, on a phone and a wrist."

    /// Everything true about the app that a person might want to check before trusting it.
    public static let facts = [
        // Said about this app as it stands, not as a promise about every app to come. A
        // pledge nobody can keep is worse than no pledge, and this one would be quoted
        // back at the first thing that ever carried a price.
        "This app is free. No adverts, nothing locked, no account.",
        "Your season stays on your phone. The app has no networking in it at all — that is checked on every build.",
        "The watch talks to the phone directly, over the link between the two paired devices.",
        "Save a copy of everything whenever you like, as one file you keep.",
    ]

    /// The line naming the build, for when somebody reports something.
    public static func versionLine(version: String?, build: String?) -> String {
        switch (version, build) {
        case let (version?, build?): "Version \(version) (\(build))"
        case let (version?, nil): "Version \(version)"
        default: "Version unknown"
        }
    }
}
