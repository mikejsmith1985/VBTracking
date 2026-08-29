// The court, on the wrist. The reason for the whole release.
//
//     4     3     2  <- on deck: the biggest box on the screen
//     5     6     1  <- serving
//
// Six boxes arranged as the players are standing. The arrangement stays still and the
// players move through it, so the corner the coach looks at never moves.
//
// The sizes are worked out in `CourtLayout` and asserted by a test that measures them,
// because no simulator can be opened on the machine this was written on.
import Combine
import SwiftUI
import VBCore
import VBPresentation

struct CourtScreen: View {
    let link: WatchLink

    /// Ticks so the "how long ago" line stays honest without the coach touching anything.
    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            if let snapshot = link.snapshot {
                VStack(spacing: 3) {
                    Header(snapshot: snapshot, freshness: link.freshness(now: now), pending: link.pending)
                    CourtGrid(snapshot: snapshot, size: geometry.size)
                }
            } else {
                VStack(spacing: 6) {
                    Text("No court yet").font(.headline)
                    Text("Start a match on the phone.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onReceive(clock) { now = $0 }
    }
}

/// What the figures cover, and whether they are still true.
private struct Header: View {
    let snapshot: CourtSnapshot
    let freshness: LinkFreshness?
    let pending: PendingQueue

    var body: some View {
        HStack(spacing: 4) {
            Text(snapshot.scopeLabel)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.secondary)
            Spacer()
            if let label = pending.label {
                Text(label).font(.system(size: 10)).foregroundStyle(.orange)
            } else if let freshness {
                // A quietly stale court is worse than a blank one: the coach would
                // substitute on a percentage that has since moved.
                Text(freshness.label)
                    .font(.system(size: 10))
                    .foregroundStyle(freshness.isCurrent ? .secondary : .orange)
            }
        }
        .accessibilityIdentifier("court-header")
    }
}

/// The six boxes, on uneven tracks so the on-deck box is the biggest without anybody moving.
private struct CourtGrid: View {
    let snapshot: CourtSnapshot
    let size: CGSize

    private var boxes: [BoxSize] {
        CourtLayout.boxes(in: (width: Double(size.width), height: Double(size.height) - 18))
    }

    var body: some View {
        VStack(spacing: gap) {
            row(0)
            row(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var gap: Double { min(size.width, size.height) * CourtLayout.gapFraction }

    private func row(_ index: Int) -> some View {
        HStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { column in
                let slot = index * 3 + column
                PlayerBox(slot: snapshot.slots[slot], hasOrder: snapshot.hasOrder)
                    .frame(width: boxes[slot].width, height: boxes[slot].height)
            }
        }
    }
}
