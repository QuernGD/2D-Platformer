import SpriteKit

#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Title screen shown before gameplay. Displays the title and one button
/// per implemented level. Levels past the highest completed one are
/// grayed out and un-tappable until their predecessor is cleared.
public final class MainMenuScene: SKScene {

    /// UserDefaults key format. Level 1 is always unlocked; level N>=2 is
    /// unlocked by writing `true` to `level_N_unlocked` after completing
    /// level N-1.
    static func unlockKey(forLevel level: Int) -> String {
        "level_\(level)_unlocked"
    }

    static func isUnlocked(level: Int) -> Bool {
        if level <= 1 { return true }
        return UserDefaults.standard.bool(forKey: unlockKey(forLevel: level))
    }

    private struct LevelButton {
        let level: Int
        let node: SKShapeNode
        let isUnlocked: Bool
    }

    private var buttons: [LevelButton] = []
    private let buttonSize = CGSize(width: 320, height: 56)

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.36, green: 0.64, blue: 1.0, alpha: 1.0)
        anchorPoint = .zero
        scaleMode = .resizeFill

        layoutMenu()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        removeAllChildren()
        buttons.removeAll()
        layoutMenu()
    }

    private func layoutMenu() {
        let centerX = size.width * 0.5
        let centerY = size.height * 0.5

        // Title
        let title = SKLabelNode(text: "PLATFORMER")
        title.fontName  = "Helvetica-Bold"
        title.fontSize  = 64
        title.fontColor = .white
        title.position  = CGPoint(x: centerX, y: centerY + 120)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode   = .center
        addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(text: "a tiny mario-physics demo")
        subtitle.fontName  = "Helvetica"
        subtitle.fontSize  = 20
        subtitle.fontColor = SKColor(white: 1, alpha: 0.85)
        subtitle.position  = CGPoint(x: centerX, y: centerY + 70)
        addChild(subtitle)

        // One button per implemented level.
        let maxLevel = LevelBuilder.maxLevel
        let spacing: CGFloat = 70
        let firstY = centerY + 10
        for i in 0..<maxLevel {
            let level = i + 1
            let unlocked = MainMenuScene.isUnlocked(level: level)
            let y = firstY - CGFloat(i) * spacing
            let node = makeButton(
                text: labelText(forLevel: level, unlocked: unlocked),
                at: CGPoint(x: centerX, y: y),
                unlocked: unlocked)
            addChild(node)
            buttons.append(LevelButton(level: level, node: node, isUnlocked: unlocked))
        }

        // Hint label
        let hint = SKLabelNode(
            text: "tap a level to play — beat it to unlock the next")
        hint.fontName  = "Helvetica"
        hint.fontSize  = 14
        hint.fontColor = SKColor(white: 1, alpha: 0.7)
        hint.position  = CGPoint(
            x: centerX,
            y: firstY - CGFloat(maxLevel) * spacing + 10)
        addChild(hint)
    }

    private func labelText(forLevel level: Int, unlocked: Bool) -> String {
        let name = LevelBuilder.name(forLevel: level)
        return unlocked ? name : "\(name)  [LOCKED]"
    }

    private func makeButton(text: String,
                            at position: CGPoint,
                            unlocked: Bool) -> SKShapeNode
    {
        let rect = CGRect(
            x: -buttonSize.width * 0.5,
            y: -buttonSize.height * 0.5,
            width: buttonSize.width,
            height: buttonSize.height)
        let node = SKShapeNode(rect: rect, cornerRadius: 10)
        if unlocked {
            node.fillColor   = SKColor(white: 0, alpha: 0.5)
            node.strokeColor = .white
        } else {
            node.fillColor   = SKColor(white: 0, alpha: 0.25)
            node.strokeColor = SKColor(white: 0.55, alpha: 0.8)
        }
        node.lineWidth = 3
        node.position  = position

        let label = SKLabelNode(text: text)
        label.fontName  = "Helvetica-Bold"
        label.fontSize  = 24
        label.fontColor = unlocked ? .white : SKColor(white: 0.6, alpha: 1)
        label.verticalAlignmentMode   = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)
        return node
    }

    // MARK: - Transition to gameplay

    private func startGame(level: Int) {
        guard let view = self.view else { return }
        let game = GameScene(size: size, level: level)
        game.scaleMode = .resizeFill
        view.presentScene(game, transition: .fade(withDuration: 0.5))
    }

    private func handleTap(at location: CGPoint) {
        for btn in buttons where btn.node.contains(location) {
            guard btn.isUnlocked else { return }
            startGame(level: btn.level)
            return
        }
    }

    // MARK: - Input

    #if os(iOS) || os(tvOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleTap(at: touch.location(in: self))
    }
    #endif

    #if os(macOS)
    public override func mouseDown(with event: NSEvent) {
        handleTap(at: event.location(in: self))
    }
    #endif
}
