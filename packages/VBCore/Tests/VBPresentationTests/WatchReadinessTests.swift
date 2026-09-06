// Saying where the watch app is, including when it is nowhere.
//
// The case that started this: a watch app that never installed looks exactly like one that is
// asleep. The phone is fine, the wrist simply never shows a court, and nothing on either
// screen says which of the two it is.
import Testing

@testable import VBPresentation

@Suite("Where the watch app is")
struct WatchReadinessTests {
    private func state(
        supported: Bool = true,
        paired: Bool = true,
        installed: Bool = true,
        reachable: Bool = true
    ) -> WatchState {
        WatchState(
            isSupported: supported, isPaired: paired, isAppInstalled: installed, isReachable: reachable
        )
    }

    @Test("A missing watch app is called out, with what to do about it")
    func namesTheMissingApp() {
        let readiness = WatchReadiness(state: state(installed: false, reachable: false))
        #expect(readiness.needsAttention, "this is the one thing somebody has to act on")
        #expect(readiness.instruction?.contains("Watch app") == true)
        #expect(readiness.instruction?.contains("Show App on Apple Watch") == true, "the actual switch")
    }

    @Test("A watch with the app on it is not a problem to be solved")
    func saysNothingToDoWhenInstalled() {
        for reachable in [true, false] {
            let readiness = WatchReadiness(state: state(reachable: reachable))
            // A wrist at somebody's side is unreachable and perfectly well. Calling that a
            // problem would train the operator to ignore the row that matters.
            #expect(!readiness.needsAttention)
            #expect(readiness.instruction == nil)
        }
    }

    @Test("No watch paired is a fact, not a fault")
    func doesNotNagAboutAnAbsentWatch() {
        let readiness = WatchReadiness(state: state(paired: false, installed: false, reachable: false))
        #expect(!readiness.needsAttention, "most phones have no watch and nothing is wrong")
        #expect(readiness.headline.contains("No Apple Watch"))
    }

    @Test("A device that cannot have a watch is told so once and left alone")
    func staysQuietWhereItCannotApply() {
        let readiness = WatchReadiness(
            state: state(supported: false, paired: false, installed: false, reachable: false)
        )
        #expect(!readiness.needsAttention)
        #expect(readiness.instruction == nil, "there is nothing anybody could do")
    }

    @Test("Something is always said, in every state")
    func alwaysSaysSomething() {
        for supported in [true, false] {
            for paired in [true, false] {
                for installed in [true, false] {
                    for reachable in [true, false] {
                        let readiness = WatchReadiness(
                            state: state(
                                supported: supported, paired: paired,
                                installed: installed, reachable: reachable
                            )
                        )
                        #expect(!readiness.headline.isEmpty)
                        // Attention is only ever asked for the one state anybody can fix.
                        if readiness.needsAttention {
                            #expect(supported && paired && !installed)
                            #expect(readiness.instruction != nil, "asking for attention without saying why")
                        }
                    }
                }
            }
        }
    }
}
