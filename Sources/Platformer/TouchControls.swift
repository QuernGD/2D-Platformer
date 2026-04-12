#if os(iOS) || os(tvOS)
import SpriteKit
import UIKit

/// Visible on-screen D-pad + action button overlay. Attach as a child of the
/// SKCameraNode so the HUD stays pinned to the view.
///
/// Multi-touch is first-class: each active UITouch is tracked independently,
/// so the player can hold RIGHT with one thumb and tap JUMP with the other.
/// The containing scene (or view) must set `view.isMultipleTouchEnabled = true`
/// for this to work — that's done in `GameViewController`.
final class TouchControls: SKNode {

    // MARK: - Visual dimensions
    private static let dpadRadius: CGFloat = 35   // 70-pt diameter
    private static let jumpRadius: CGFloat = 40   // 80-pt diameter
    private static let runRadius:  CGFloat = 30   // 60-pt diameter

    /// Extra hit-test padding beyond the visual circle.
    private static let hitPadding: CGFloat = 20

    // MARK: - Button nodes
    private let leftButton:  SKShapeNode
    private let rightButton: SKShapeNode
    private let jumpButton:  SKShapeNode
    private let runButton:   SKShapeNode

    private enum Button: Hashable { case left, right, jump, run }
    private var touchButtons: [ObjectIdentifier: Button] = [:]

    // MARK: - Exposed input state
    var leftHeld:  Bool { buttonActive(.left) }
    var rightHeld: Bool { buttonActive(.right) }
    var jumpHeld:  Bool { buttonActive(.jump) }
    var runHeld:   Bool { buttonActive(.run) }

    /// Edge-triggered: `true` for exactly one read after the jump button
    /// becomes pressed. Consume via `consumeJumpPress()`.
    private var jumpEdge: Bool = false

    // MARK: - Init
    override init() {
        leftButton  = TouchControls.makeButton(radius: TouchControls.dpadRadius, label: "<")
        rightButton = TouchControls.makeButton(radius: TouchControls.dpadRadius, label: ">")
        jumpButton  = TouchControls.makeButton(radius: TouchControls.jumpRadius, label: "A")
        runButton   = TouchControls.makeButton(radius: TouchControls.runRadius,  label: "B")
        super.init()
        zPosition = 1_000
        addChild(leftButton)
        addChild(rightButton)
        addChild(jumpButton)
        addChild(runButton)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("not implemented") }

    private static func makeButton(radius: CGFloat, label: String) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor   = SKColor(white: 0, alpha: 0.4)
        node.strokeColor = SKColor(white: 1, alpha: 0.6)
        node.lineWidth   = 2

        let text = SKLabelNode(text: label)
        text.fontName            = "Helvetica-Bold"
        text.fontSize            = radius * 1.1
        text.fontColor           = .white
        text.verticalAlignmentMode   = .center
        text.horizontalAlignmentMode = .center
        node.addChild(text)
        return node
    }

    /// Position the buttons for the current scene size and safe-area insets.
    /// Call whenever the scene's size or insets change.
    func layout(sceneSize: CGSize, safeInsets: UIEdgeInsets) {
        // When this node is a child of an SKCameraNode, its coordinate origin
        // is the camera center. The visible region spans
        //     (-w/2, -h/2)  ...  (w/2, h/2)
        // in its parent's (the camera's) space.
        let halfW = sceneSize.width  * 0.5
        let halfH = sceneSize.height * 0.5
        let edgeInset: CGFloat = 25

        // D-pad at bottom-left
        let leftX = -halfW + safeInsets.left + edgeInset + TouchControls.dpadRadius
        let leftY = -halfH + safeInsets.bottom + edgeInset + TouchControls.dpadRadius
        leftButton.position = CGPoint(x: leftX, y: leftY)

        let rightX = leftX + TouchControls.dpadRadius * 2 + 25
        rightButton.position = CGPoint(x: rightX, y: leftY)

        // Jump at bottom-right
        let jumpX = halfW - safeInsets.right - edgeInset - TouchControls.jumpRadius
        let jumpY = -halfH + safeInsets.bottom + edgeInset + TouchControls.jumpRadius
        jumpButton.position = CGPoint(x: jumpX, y: jumpY)

        // Run to the left of jump, slightly lower
        let runX = jumpX - TouchControls.jumpRadius - TouchControls.runRadius - 20
        let runY = jumpY - (TouchControls.jumpRadius - TouchControls.runRadius)
        runButton.position = CGPoint(x: runX, y: runY)
    }

    // MARK: - Hit test

    private func hitTest(point: CGPoint) -> Button? {
        // `point` is expected to already be in this node's coordinate space.
        if distance(point, leftButton.position)
            <= TouchControls.dpadRadius + TouchControls.hitPadding { return .left }
        if distance(point, rightButton.position)
            <= TouchControls.dpadRadius + TouchControls.hitPadding { return .right }
        if distance(point, jumpButton.position)
            <= TouchControls.jumpRadius + TouchControls.hitPadding { return .jump }
        if distance(point, runButton.position)
            <= TouchControls.runRadius  + TouchControls.hitPadding { return .run }
        return nil
    }

    @inline(__always)
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private func buttonActive(_ b: Button) -> Bool {
        for (_, btn) in touchButtons where btn == b { return true }
        return false
    }

    // MARK: - Touch routing
    //
    // The containing scene forwards its touch events into these methods.
    // Each returns `true` if the touch was consumed by a button — that lets
    // the scene distinguish "touched a HUD button" from "touched the world".

    @discardableResult
    func touchBegan(_ touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        guard let button = hitTest(point: point) else { return false }
        touchButtons[ObjectIdentifier(touch)] = button
        if button == .jump {
            jumpEdge = true
        }
        setPressedVisual(for: button, pressed: true)
        return true
    }

    func touchMoved(_ touch: UITouch) {
        let id = ObjectIdentifier(touch)
        guard let oldButton = touchButtons[id] else { return }
        let point = touch.location(in: self)
        let newButton = hitTest(point: point)
        guard newButton != oldButton else { return }

        // Dropped off the old button's hit area.
        if !buttonActive(oldButton) || newButton != nil {
            setPressedVisual(for: oldButton, pressed: false)
        }

        if let new = newButton {
            touchButtons[id] = new
            setPressedVisual(for: new, pressed: true)
            if new == .jump { jumpEdge = true }
        } else {
            touchButtons.removeValue(forKey: id)
        }
    }

    func touchEnded(_ touch: UITouch) {
        let id = ObjectIdentifier(touch)
        guard let button = touchButtons.removeValue(forKey: id) else { return }
        if !buttonActive(button) {
            setPressedVisual(for: button, pressed: false)
        }
    }

    /// Read-and-clear the edge-triggered jump press. Returns `true` at most
    /// once per tap.
    func consumeJumpPress() -> Bool {
        let v = jumpEdge
        jumpEdge = false
        return v
    }

    private func setPressedVisual(for button: Button, pressed: Bool) {
        let node: SKShapeNode
        switch button {
        case .left:  node = leftButton
        case .right: node = rightButton
        case .jump:  node = jumpButton
        case .run:   node = runButton
        }
        node.fillColor = SKColor(
            white: pressed ? 0.35 : 0,
            alpha: pressed ? 0.7  : 0.4)
    }
}
#endif
