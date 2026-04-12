import SpriteKit

#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Title screen shown before gameplay. Displays a big title and a single
/// "Level 1" button. Future level buttons can be added by extending
/// `levelButtons`.
public final class MainMenuScene: SKScene {

    private var level1Button: SKShapeNode!
    private let buttonSize = CGSize(width: 240, height: 70)

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.36, green: 0.64, blue: 1.0, alpha: 1.0)
        anchorPoint = .zero
        scaleMode = .resizeFill

        layoutMenu()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        removeAllChildren()
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
        title.position  = CGPoint(x: centerX, y: centerY + 100)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode   = .center
        addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(text: "a tiny mario-physics demo")
        subtitle.fontName  = "Helvetica"
        subtitle.fontSize  = 20
        subtitle.fontColor = SKColor(white: 1, alpha: 0.85)
        subtitle.position  = CGPoint(x: centerX, y: centerY + 50)
        addChild(subtitle)

        // Level 1 button
        level1Button = makeButton(text: "LEVEL 1",
                                  at: CGPoint(x: centerX, y: centerY - 40))
        addChild(level1Button)

        // Hint label
        let hint = SKLabelNode(text: "tap to play")
        hint.fontName  = "Helvetica"
        hint.fontSize  = 14
        hint.fontColor = SKColor(white: 1, alpha: 0.7)
        hint.position  = CGPoint(x: centerX, y: centerY - 110)
        addChild(hint)
    }

    private func makeButton(text: String, at position: CGPoint) -> SKShapeNode {
        let rect = CGRect(
            x: -buttonSize.width * 0.5,
            y: -buttonSize.height * 0.5,
            width: buttonSize.width,
            height: buttonSize.height)
        let node = SKShapeNode(rect: rect, cornerRadius: 12)
        node.fillColor   = SKColor(white: 0, alpha: 0.5)
        node.strokeColor = .white
        node.lineWidth   = 3
        node.position    = position
        node.name        = "level1"

        let label = SKLabelNode(text: text)
        label.fontName  = "Helvetica-Bold"
        label.fontSize  = 30
        label.fontColor = .white
        label.verticalAlignmentMode   = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)
        return node
    }

    // MARK: - Transition to gameplay

    private func startGame() {
        guard let view = self.view else { return }
        let game = GameScene(size: size)
        game.scaleMode = .resizeFill
        view.presentScene(game, transition: .fade(withDuration: 0.5))
    }

    // MARK: - Input

    #if os(iOS) || os(tvOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        if level1Button.contains(location) {
            startGame()
        }
    }
    #endif

    #if os(macOS)
    public override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        if level1Button.contains(location) {
            startGame()
        }
    }
    #endif
}
