// The five-serve rule, on the wrist.
//
// It does not buzz once. A single tap on the wrist is exactly the thing a coach misses
// while watching a rally, and missing it means the wrong player serves a sixth. So it keeps
// buzzing, on a beat, until somebody clears it — the same way an alarm does, and for the
// same reason.
//
// Deliberately no `WKExtendedRuntimeSession`. A repeating haptic does not need one while the
// app is on screen, and the session types that would grant it (mindfulness and the rest)
// mute the wearer's own notifications — which would trade a rotation reminder for every text
// message and camera alert of the evening. That is not a trade this app gets to make.
import Combine
import SwiftUI
import VBCore
import VBPresentation
import WatchKit

private let rotateBeat: TimeInterval = 1.5

struct RotateAlert: View {
    let notice: ServeLimitNotice

    /// False when the coach has kept the alert but silenced it.
    var shouldBuzz = true

    let onDismiss: () -> Void

    /// The beat the haptic runs on.
    ///
    /// Slow enough to be a reminder rather than an assault, quick enough that a coach
    /// looking away for a rally still feels several.
    private let pulse = Timer.publish(every: rotateBeat, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 2) {
            Text("⟳").font(.system(size: 34)).foregroundStyle(.orange)
            Text("ROTATE").font(.system(size: 19, weight: .heavy)).foregroundStyle(.orange)

            if let finished = notice.finishedNumber {
                Text("\(finished) has served \(serveLimit)")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            if let next = notice.nextNumber {
                Text("Next: \(next)").font(.system(size: 17, weight: .heavy))
            } else {
                // Without an order the same player still holds the ball, and naming them
                // would read as permission to serve a sixth.
                Text("Pick the server").font(.system(size: 13, weight: .bold))
            }

            Button("Got it", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.top, 2)
                .accessibilityIdentifier("rotate-dismiss")
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92))
        .accessibilityIdentifier("rotate-alert")
        // The first buzz lands with the alert, not a beat after it.
        .onAppear { buzz() }
        .onReceive(pulse) { _ in buzz() }
    }

    /// A heavier haptic than a recorded serve gets: this one means stop, not "noted".
    private func buzz() {
        guard shouldBuzz else { return }
        WKInterfaceDevice.current().play(.notification)
    }
}
