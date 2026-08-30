// What the app is, and the one place it says thank you.
//
// Reached from the bottom of the Season screen, which is read between matches. Nothing here
// ever appears on its own: no launch prompt, no sheet over a game, no reminder. Somebody
// who wants to find this can, and somebody who does not will never see it.
import SwiftUI
import VBCore
import VBPresentation

/// Where a thank-you goes.
///
/// One place, so there is one thing to change if the page ever moves. An address that does
/// not build shows no tip jar at all rather than a dead button.
private let supportLink = SupportLink("https://buymeacoffee.com/mikejsmith1985")

struct AboutScreen: View {
    private var version: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private var build: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Volleyball Serve Tracker").font(.title3.bold())
                    Text(About.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(About.facts, id: \.self) { fact in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·").font(.headline).foregroundStyle(.tertiary)
                        Text(fact).font(.footnote)
                    }
                }
            }

            if let supportLink {
                Section {
                    // A link, not a payment field. Apple leaves exactly one lawful way to be
                    // paid outside their system in a free app, and this is it: the browser
                    // takes over from here.
                    Link(destination: supportLink.url) {
                        Label(SupportLink.action, systemImage: "cup.and.saucer")
                    }
                    .accessibilityIdentifier("support-link")

                    Text(SupportLink.invitation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(About.versionLine(version: version, build: build))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
