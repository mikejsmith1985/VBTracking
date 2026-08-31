// A way out of every keyboard in the app.

import SwiftUI
import UIKit

/// Gives a screen's keyboard a Done button, and lets a scroll push it away.
///
/// A `.numberPad` keyboard has no return key. On the roster that left an operator typing a
/// jersey number with the keyboard covering the tab bar and nothing on screen that would
/// dismiss it -- the page could not be left at all without force-quitting the app.
///
/// SwiftUI's own answer is `@FocusState`, but it only resigns a field the screen has
/// enumerated and bound in advance. There is no framework call for "put away whichever
/// keyboard is up", which is the thing every one of these screens actually needs, so the
/// responder chain is asked directly. That is the documented gap this works around.
struct KeyboardDismissable: ViewModifier {
    func body(content: Content) -> some View {
        content
            // A drag down over the list dismisses it, which is what a hand reaches for first.
            .scrollDismissesKeyboard(.interactively)
            // And a button, because a list too short to scroll cannot be dragged.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { resignAnyFirstResponder() }
                        .accessibilityIdentifier("dismiss-keyboard")
                }
            }
    }

    /// Asks whatever holds the keyboard to give it up.
    private func resignAnyFirstResponder() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    /// Every screen that takes typing must offer a way to stop.
    func keyboardDismissable() -> some View {
        modifier(KeyboardDismissable())
    }
}
