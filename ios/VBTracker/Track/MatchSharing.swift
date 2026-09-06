// Sharing the match, on the screen the match is on.
//
// It used to live in the Season tab, next to backups and restores, which is where somebody
// looks once a season rather than once a game. Sharing is not a setting -- it is something
// you do to the match in front of you, at the moment it starts, so it belongs here.
//
// There is one button, and it only exists while a match does. Nobody has to decide which of
// two phones taps which of two buttons before the first serve: the phone with the match
// shares it, the invitation says which way it travels, and the other phone never chooses
// anything at all.
import SwiftUI
import VBCore
import VBPresentation

/// One slim row under the header: share this match, or say who it is being shared with.
struct MatchSharing: View {
    let peers: PeerLink
    @Binding var isInviting: Bool

    var body: some View {
        HStack(spacing: 8) {
            if peers.isSharing {
                Image(systemName: peers.state.isLive ? "antenna.radiowaves.left.and.right" : "dot.radiowaves.left.and.right")
                Text(peers.state.isLive ? peers.state.label(as: peers.role) : peers.waitingLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                // Offered again rather than only once: an invitation can be missed, declined,
                // or sent to the wrong person, and the answer to all three is to send another.
                Button("Invite") { isInviting = true }
                    .accessibilityIdentifier("invite-again")
                Button("Stop") { peers.stop() }
                    .accessibilityIdentifier("stop-sharing")
            } else {
                Image(systemName: "person.2.wave.2")
                Button("Share this match") { isInviting = true }
                    .accessibilityIdentifier("share-match")
                Spacer(minLength: 4)
            }
        }
        .font(.caption)
        .buttonStyle(.borderless)
        .foregroundStyle(peers.state.isLive ? Color.green : Color.secondary)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .accessibilityIdentifier("match-sharing")
    }
}
