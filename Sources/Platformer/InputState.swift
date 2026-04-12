import CoreGraphics

/// Per-frame input snapshot passed into the player's update method.
///
/// `jumpPressedThisFrame` is a one-shot edge trigger that gets fed into the
/// jump buffer. `jumpHeld` is a continuous state used for variable jump
/// height (weak gravity only applies while the button is still held).
struct InputState {
    var leftHeld: Bool = false
    var rightHeld: Bool = false
    var runHeld: Bool = false                // the SMB "B" button
    var jumpHeld: Bool = false               // the SMB "A" button
    var jumpPressedThisFrame: Bool = false   // rising edge of jumpHeld

    /// Horizontal axis: -1 for left, +1 for right, 0 for none / both.
    var horizontal: CGFloat {
        (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
    }
}
