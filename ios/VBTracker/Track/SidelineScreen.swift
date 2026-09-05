// The court, full screen, for a phone propped up beside it.
//
// The case: somebody coaching wants to glance at a phone rather than a wrist, and wants more
// than the next server -- they want everybody available and what each has done tonight.
//
// The screen is kept awake for as long as this is open and released the moment it closes. A
// phone that stays lit after somebody has put it away is a flat battery by the third set.
//
// Nothing here is tappable but the way out. It is a board, not a control panel: a phone lying
// on a scorer's table gets knocked, and a mis-tap on this screen must not be able to record
// anything.
import SwiftUI
import VBCore
import VBPresentation

struct SidelineScreen: View {
    let store: Store
    @Environment(\.dismiss) private var dismiss

    private var sideline: Sideline? { Sideline(state: store.state) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let sideline {
                VStack(spacing: 10) {
                    header(sideline)
                    CourtBoard(slots: sideline.court)
                    if !sideline.bench.isEmpty { BenchStrip(bench: sideline.bench) }
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    Text("No match in progress").font(.title2.bold())
                    Text("Start a game, or wait for one to arrive from the other phone.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding()
            }

            VStack {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.callout.bold())
                        .padding(10)
                        .accessibilityIdentifier("close-sideline")
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        // Kept awake only while this is on screen, and asked for by name: a phone that is
        // also receiving a match keeps its own hold when this closes.
        .onAppear { AwakeScreen.hold(.board) }
        .onDisappear { AwakeScreen.release(.board) }
    }

    private func header(_ sideline: Sideline) -> some View {
        HStack {
            Text(sideline.scopeLabel).font(.headline).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

/// Six boxes laid out as the players are standing, the serving corner bottom right.
private struct CourtBoard: View {
    let slots: [CourtSlot]

    var body: some View {
        VStack(spacing: 8) {
            row(0)
            row(1)
        }
    }

    private func row(_ index: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(slots.dropFirst(index * 3).prefix(3)), id: \.position) { slot in
                CourtCard(slot: slot)
            }
        }
    }
}

/// One position on the court, at a size meant to be read from a metre away.
private struct CourtCard: View {
    let slot: CourtSlot

    var body: some View {
        VStack(spacing: 2) {
            Text(text(number: slot.number))
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            if slot.number != nil {
                Text(text(percentage: slot.inPercentage))
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(text(count: slot.points))
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("pts").font(.system(size: 12)).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(fill))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(border, lineWidth: slot.isServing || slot.isOnDeck ? 3 : 1)
        )
        .overlay(alignment: .topLeading) { marker }
    }

    private var fill: Color {
        slot.isOnDeck ? Color.orange.opacity(0.22) : Color.white.opacity(0.06)
    }

    private var border: Color {
        slot.isServing ? .cyan : (slot.isOnDeck ? .orange : Color.white.opacity(0.12))
    }

    /// Nothing is carried by colour alone: the two boxes that matter are labelled too, so
    /// they still read to a colour-blind eye and at a glance from across a gym.
    @ViewBuilder private var marker: some View {
        if slot.isServing {
            corner("serving", .cyan)
        } else if slot.isOnDeck {
            corner("next", .orange)
        }
    }

    private func corner(_ word: String, _ tint: Color) -> some View {
        Text(word)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
    }
}

/// Everybody not on court, in jersey order, with what they have done tonight.
private struct BenchStrip: View {
    let bench: [BenchPlayer]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BENCH").font(.caption2.bold()).foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(bench) { player in
                        VStack(spacing: 1) {
                            Text(text(number: player.number))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Text(text(percentage: player.inPercentage))
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("\(text(count: player.points)) pts")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minWidth: 54)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                    }
                }
            }
        }
        .frame(maxHeight: 96)
    }
}
