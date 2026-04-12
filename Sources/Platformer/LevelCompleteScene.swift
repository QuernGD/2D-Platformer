import SpriteKit

#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Shown after the player reaches the flagpole. Displays coin count and
/// elapsed time, with "Retry" and "Main Menu" actions.
public final class LevelCompleteScene: SKScene {

    public let coinCount: Int
    public let elapsedSeconds: TimeInterval

    private var retryButton: SKShapeNode!
    private var menuButton: SKShapeNode!
    private let buttonSize = CGSize(width: 220, height: 60)

    public init(size: CGSize, coins: Int, elapsed: TimeInterval) {
        self.coinCount = coins
        self.elapsedSeconds = elapsed
        super.init(size: size)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.18, blue: 0.32, alpha: 1.0)
        anchorPoint = .zero
        scaleMode = .resizeFill
        layoutScene()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        removeAllChildren()
        layoutScene()
    }

    private func layoutScene() {
        let cx = size.width  * 0.5
        let cy = size.height * 0.5

        let title = SKLabelNode(text: "LEVEL COMPLETE!")
        title.fontName  = "Helvetica-Bold"
        title.fontSize  = 48
        title.fontColor = .white
        title.position  = CGPoint(x: cx, y: cy + 130)
        addChild(title)

        let coinLine = SKLabelNode(text: "Coins: \(coinCount)")
        coinLine.fontName  = "Helvetica-Bold"
        coinLine.fontSize  = 28
        coinLine.fontColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        coinLine.position  = CGPoint(x: cx, y: cy + 60)
        addChild(coinLine)

        let timeLine = SKLabelNode(text: String(format: "Time: %.1fs", elapsedSeconds))
        timeLine.fontName  = "Helvetica"
        timeLine.fontSize  = 24
        timeLine.fontColor = .white
        timeLine.position  = CGPoint(x: cx, y: cy + 20)
        addChild(timeLine)

        retryButton = makeButton(
            text: "RETRY",
            at: CGPoint(x: cx, y: cy - 50),
            name: "retry")
        addChild(retryButton)

        menuButton = makeButton(
            text: "MAIN MENU",
            at: CGPoint(x: cx, y: cy - 130),
            name: "menu")
        addChild(menuButton)
    }

    private func makeButton(text: String, at position: CGPoint, name: String) -> SKShapeNode {
        let rect = CGRect(
            x: -buttonSize.width * 0.5,
            y: -buttonSize.height * 0.5,
            width: buttonSize.width,
            height: buttonSize.height)
        let node = SKShapeNode(rect: rect, cornerRadius: 10)
        node.fillColor   = SKColor(white: 0, alpha: 0.55)
        node.strokeColor = .white
        node.lineWidth   = 2.5
        node.position    = position
        node.name        = name

        let label = SKLabelNode(text: text)
        label.fontName  = "Helvetica-Bold"
        label.fontSize  = 26
        label.fontColor = .white
        label.verticalAlignmentMode   = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)
        return node
    }

    // MARK: - Actions

    private func retry() {
        guard let view = self.view else { return }
        let game = GameScene(size: size)
        game.scaleMode = .resizeFill
        view.presentScene(game, transition: .fade(withDuration: 0.4))
    }

    private func returnToMenu() {
        guard let view = self.view else { return }
        let menu = MainMenuScene(size: size)
        menu.scaleMode = .resizeFill
        view.presentScene(menu, transition: .fade(withDuration: 0.4))
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

    private func handleTap(at location: CGPoint) {
        if retryButton.contains(location) {
            retry()
        } else if menuButton.contains(location) {
            returnToMenu()
        }
    }
}
