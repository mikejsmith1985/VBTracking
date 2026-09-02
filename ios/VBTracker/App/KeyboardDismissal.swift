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
            // Any scroll of the list dismisses it, not a deliberate drag that tracks the
            // finger. Interactive dismissal reads as "the keyboard is stuck" to somebody
            // who flicks the list and watches it come straight back.
            .scrollDismissesKeyboard(.immediately)
            // And a button, because a list too short to scroll cannot be dragged.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                        .font(.body.bold())
                        .accessibilityIdentifier("dismiss-keyboard")
                }
            }
    }

}

/// Puts away whichever keyboard is up, from anywhere.
///
/// Free of any view, because the screens that need it most need it after an action rather
/// than after a tap on a button: adding a player leaves the number field focused, and a
/// keyboard that stays up over the tab bar is the same trap whether it was opened by hand
/// or left behind by a form that finished.
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}

extension View {
    /// Every screen that takes typing must offer a way to stop.
    func keyboardDismissable() -> some View {
        modifier(KeyboardDismissable())
    }
}
