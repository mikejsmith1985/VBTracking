// Sharing the match, on the screen the match is on.
//
// It used to live in the Season tab, next to backups and restores, which is where somebody
// looks once a season rather than once a game. Sharing is not a setting -- it is something
// you do to the match in front of you, at the moment it starts, so it belongs here.
//
// It is drawn as a button and not as a line of text. The first version tinted the whole row
// secondary grey at caption size, which put "Share this match" directly under "points on
// serve" in the same colour and the same weight -- so it read as another caption, and the one
// person who knew it existed could not find it.
import SwiftUI
import VBCore
import VBPresentation

/// One row under the header: share this match, or say who it is being shared with.
struct MatchSharing: View {
    let peers: PeerLink
    @Binding var isInviting: Bool

    var body: some View {
        HStack(spacing: 8) {
            if peers.isSharing {
                Label {
                    Text(peers.state.isLive ? peers.state.label(as: peers.role) : peers.waitingLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } icon: {
                    Image(systemName: peers.state.isLive
                        ? "antenna.radiowaves.left.and.right"
                        : "dot.radiowaves.left.and.right")
                }
                .font(.caption)
                .foregroundStyle(peers.state.isLive ? Color.green : Color.secondary)

                Spacer(minLength: 4)

                // The way to reach a phone that cannot see this one -- somebody not in the
                // app, or not in the room yet. It sends a file, which is why it is here and
                // not on the way in: the ordinary case needs no file at all.
                Button("Invite") { isInviting = true }
                    .accessibilityIdentifier("invite-again")
                Button("Stop") { peers.stop() }
                    .accessibilityIdentifier("stop-sharing")
            } else {
                // Starts sharing and nothing else. Putting a share sheet in the way of it
                // meant a file, a picker and an "open with" stood between tapping share and
                // being shared -- when the other phone can simply see this one and offer to
                // watch. Handing somebody a file is the fallback now, behind Invite.
                Button {
                    peers.startSending()
                } label: {
                    Label("Share this match", systemImage: "person.2.wave.2")
                }
                .accessibilityIdentifier("share-match")
                Spacer(minLength: 4)
            }
        }
        // The app's own language for anything tappable: a tinted capsule. Everything else on
        // this screen that does something -- End match, Order, Change, Undo -- is one.
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(.cyan)
        .font(.caption.bold())
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .accessibilityIdentifier("match-sharing")
    }
}
