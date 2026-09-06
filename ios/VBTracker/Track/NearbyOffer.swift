// "Somebody nearby is sharing a match." One tap to watch it.
//
// This is the whole of the other person's setup now. It replaced AirDropping a file, which
// answered one question -- which phone -- and charged the receiver a file picker and an "open
// with" to answer it. A phone sharing a match already says its name into the room.
//
// It appears only when there is something to say. An app that reports "nobody is sharing"
// every time it is opened has taught everybody to ignore that row by the second week.
import SwiftUI
import VBCore
import VBPresentation

struct NearbyOffer: View {
    let peers: PeerLink

    /// Freshness is a matter of seconds, and a view does not redraw because time passed. A
    /// phone that walked out of the gym must stop being offered without anybody touching the
    /// screen, so the clock drives the row rather than the other way round.
    @State private var now = Date()
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let offer = peers.nearbyOffer(at: now) {
                row(offer, phones: peers.nearbyPhones(at: now))
            }
        }
        .onReceive(tick) { now = $0 }
    }

    @ViewBuilder
    private func row(_ offer: String, phones: [NearbyPhone]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text(offer).font(.caption.bold())
                Spacer(minLength: 4)

                // One phone is the ordinary case and gets one button. Several is two courts
                // in one gym, and guessing between them would put somebody else's match on
                // this screen -- so each is named and the operator picks.
                if phones.count == 1, let only = phones.first {
                    Button("Watch") { peers.watch(only) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("watch-nearby")
                }
            }

            if phones.count > 1 {
                ForEach(phones) { phone in
                    Button("Watch \(phone.shownName)") { peers.watch(phone) }
                        .font(.caption)
                        .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cyan.opacity(0.12))
        .accessibilityIdentifier("nearby-offer")
    }
}
