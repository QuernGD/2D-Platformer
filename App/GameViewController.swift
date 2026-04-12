import UIKit
import SpriteKit

final class GameViewController: UIViewController {

    override func loadView() {
        self.view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
        // REQUIRED for the on-screen D-pad + jump to register simultaneously.
        // UIView's default is single-touch only.
        skView.isMultipleTouchEnabled = true

        let menu = MainMenuScene(size: skView.bounds.size)
        menu.scaleMode = .resizeFill
        skView.presentScene(menu)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
