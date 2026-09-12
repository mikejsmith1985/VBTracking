// The court on the lock screen.
//
// A Live Activity rather than a widget: a widget refreshes on a timeline the system decides,
// and a court that updates when iOS feels like it is a court nobody may act on.
//
// The one rule this screen exists to keep is `Glance`: it either vouches for the figures or
// it shows none at all. A percentage on a lock screen is read as a percentage however it is
// styled, and a coach reading a frozen one has no way to know it froze -- they will
// substitute on it exactly as confidently as on a live one.
import ActivityKit
import SwiftUI
import VBPresentation
import WidgetKit

@main
struct GlanceBundle: WidgetBundle {
    var body: some Widget {
        CourtLiveActivity()
    }
}

struct CourtLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourtActivityAttributes.self) { context in
            LockScreenCourt(
                glance: Glance(court: context.state.court),
                opponent: context.attributes.opponent
            )
            .padding(12)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.cyan)
        } dynamicIsland: { context in
            let glance = Glance(court: context.state.court)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    LockScreenCourt(glance: glance, opponent: context.attributes.opponent)
                        .padding(6)
                }
            } compactLeading: {
                Image(systemName: "figure.volleyball")
            } compactTrailing: {
                // The one figure worth a glance this small: who serves next.
                Text(glance.onDeckNumber.map { "#\($0)" } ?? "\u{2014}")
                    .font(.caption.bold())
            } minimal: {
                Image(systemName: "figure.volleyball")
            }
        }
    }
}

/// The court, or an honest blank where the court used to be.
struct LockScreenCourt: View {
    let glance: Glance
    let opponent: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            if glance.hasCourt {
                CourtRows(slots: glance.slots)
            } else {
                // No figures at all. Not dimmed, not greyed, not marked stale: absent, with a
                // sentence saying what to do about it.
                Text(glance.headline)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(opponent.isEmpty ? "Match in progress" : opponent)
                .font(.caption.bold())
                .lineLimit(1)
            Spacer()
            if let onDeck = glance.onDeckNumber {
                Text("next #\(onDeck)")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
            Text(glance.age)
                .font(.caption2)
                // Named as Colors on both sides: `.secondary` alone is a hierarchical style,
                // not a colour, and the two cannot share a ternary.
                .foregroundStyle(glance.isVouchedFor ? Color.secondary : Color.orange)
        }
    }
}

/// Six boxes in two rows, laid out as the players are standing.
private struct CourtRows: View {
    let slots: [SnapshotSlot]

    var body: some View {
        VStack(spacing: 3) {
            row(0)
            row(1)
        }
    }

    private func row(_ index: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(slots.dropFirst(index * 3).prefix(3)), id: \.court) { slot in
                GlanceBox(slot: slot)
            }
        }
    }
}

/// One position, at the smallest size a jersey number is still readable at arm's length.
private struct GlanceBox: View {
    let slot: SnapshotSlot

    var body: some View {
        VStack(spacing: 0) {
            Text(text(number: slot.number))
                .font(.system(size: slot.isOnDeck ? 20 : 15, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if slot.number != nil {
                Text(text(percentage: slot.inPercentage))
                    .font(.system(size: slot.isOnDeck ? 11 : 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(slot.isOnDeck ? Color.orange.opacity(0.25) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(border, lineWidth: slot.isServing || slot.isOnDeck ? 1.5 : 0.5)
        )
    }

    private var border: Color {
        slot.isServing ? .cyan : (slot.isOnDeck ? .orange : Color.white.opacity(0.15))
    }
}
