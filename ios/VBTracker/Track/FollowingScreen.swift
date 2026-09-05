// The Track tab on a phone that is watching somebody else's match.
//
// It records nothing, so it shows nothing that records: no outcome buttons, no picker, no
// undo, no serve limit alert. A control that cannot be used is a control somebody taps anyway
// and then wonders about, and on a sideline that wondering costs a rotation.
//
// What is left is the board -- the six on court and the bench beside them -- which is the
// only thing this phone is for.
import SwiftUI
import VBCore
import VBPresentation

struct FollowingScreen: View {
    let store: Store
    let peers: PeerLink?

    @State private var isShowingBoard = false

    private var sideline: Sideline? { Sideline(state: store.state) }

    var body: some View {
        VStack(spacing: 0) {
            NoticeBanner(notice: store.notice)
            banner

            if sideline != nil {
                BoardPreview(store: store)
                    .padding(.horizontal, 10)

                Button {
                    isShowingBoard = true
                } label: {
                    Label("Full screen", systemImage: "rectangle.inset.filled.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(10)
                .accessibilityIdentifier("open-sideline")
            } else {
                EmptyState(
                    title: "Waiting for the match",
                    detail: "The court appears here as soon as the other phone starts one."
                )
            }

            Spacer(minLength: 0)
        }
        .fullScreenCover(isPresented: $isShowingBoard) { SidelineScreen(store: store) }
    }

    /// Says whose match this is, so nobody wonders where the buttons went, and says the one
    /// thing about this phone that is not obvious: it has to stay on.
    ///
    /// iOS suspends an app the moment the phone locks and the link goes with it. The screen
    /// is held awake so it will not happen by itself, but a hand on the side button still
    /// does it, and a court that stopped moving looks exactly like a court where nobody has
    /// served yet.
    private var banner: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                Text(peers?.role.explanation ?? "Watching another phone's match.")
                    .font(.caption)
                Spacer()
            }
            Text("Leave this phone unlocked. Locking it stops the match arriving.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .accessibilityIdentifier("following-notice")
    }
}

/// The same board the full-screen view draws, at whatever size the tab leaves it.
private struct BoardPreview: View {
    let store: Store

    var body: some View {
        if let sideline = Sideline(state: store.state) {
            VStack(alignment: .leading, spacing: 6) {
                Text(sideline.scopeLabel).font(.caption.bold()).foregroundStyle(.secondary)
                CourtGrid(slots: sideline.court)
                if !sideline.bench.isEmpty { BenchRow(bench: sideline.bench) }
            }
        }
    }
}

/// Six boxes in two rows, the serving corner bottom right.
private struct CourtGrid: View {
    let slots: [CourtSlot]

    var body: some View {
        VStack(spacing: 6) {
            row(0)
            row(1)
        }
    }

    private func row(_ index: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(slots.dropFirst(index * 3).prefix(3)), id: \.position) { slot in
                Box(slot: slot)
            }
        }
    }
}

private struct Box: View {
    let slot: CourtSlot

    var body: some View {
        VStack(spacing: 1) {
            Text(text(number: slot.number))
                .font(.system(size: slot.isOnDeck ? 38 : 28, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            if slot.number != nil {
                Text(text(percentage: slot.inPercentage))
                    .font(.system(size: slot.isOnDeck ? 16 : 13, weight: .semibold).monospacedDigit())
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(text(count: slot.points))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("pts").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(slot.isOnDeck ? Color.orange.opacity(0.22) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    slot.isServing ? Color.cyan : (slot.isOnDeck ? Color.orange : Color.white.opacity(0.12)),
                    lineWidth: slot.isServing || slot.isOnDeck ? 2 : 1
                )
        )
    }
}

/// Everybody not on court, in jersey order.
private struct BenchRow: View {
    let bench: [BenchPlayer]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("BENCH").font(.caption2.bold()).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(bench) { player in
                        VStack(spacing: 0) {
                            Text(text(number: player.number))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(text(percentage: player.inPercentage))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 46)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.05)))
                    }
                }
            }
        }
    }
}
