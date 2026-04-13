import SpriteKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Main scene. Runs a fixed-timestep physics loop on top of SpriteKit, hosts
/// the tile map and entities, and wires the on-screen TouchControls (iOS) or
/// keyboard (macOS) into the shared `InputState`.
public final class GameScene: SKScene {

    // MARK: - Constants
    public static let tileSize:      CGFloat = 32
    public static let fixedTimeStep: CGFloat = 1.0 / 60.0

    // MARK: - Game state

    private enum GameState {
        case playing   // normal gameplay
        case paused    // pause overlay up
        case dying     // death animation running
        case gameOver  // game-over overlay up (out of lives)
        case complete  // transitioning to LevelCompleteScene
    }
    private var state: GameState = .playing

    // MARK: - Selected level
    /// Which level this scene is playing. Set via the convenience
    /// initializer below; defaults to 1 when the scene is constructed
    /// with the plain `init(size:)`.
    private var currentLevel: Int = 1

    public convenience init(size: CGSize, level: Int) {
        self.init(size: size)
        self.currentLevel = level
    }

    // MARK: - World state
    private var map: TileMap!
    private var player: Player!
    private var enemies: [Goomba] = []
    private var camController: CameraController!
    private var flagpoleColumn: Int = 0

    /// Tile visuals keyed by `row * map.width + col`. Used to update tiles
    /// in place when a coin is collected or a question block is hit.
    private var tileNodes: [Int: SKNode] = [:]

    // MARK: - HUD + progression
    private var coinCount: Int = 0
    private var coinLabel: SKLabelNode!

    private var lives: Int = 3
    private var livesLabel: SKLabelNode!

    private var pauseButton: SKShapeNode!

    /// Seconds of gameplay elapsed — paused when not playing.
    private var gameTime: CGFloat = 0

    // Active overlays (pause / game over). Only one is up at a time.
    private var activeOverlay: SKNode?
    /// Named hit-test rects for overlay buttons.
    private var overlayButtons: [(name: String, node: SKShapeNode)] = []

    // MARK: - Input
    private var input = InputState()

    #if os(iOS) || os(tvOS)
    private var touchControls: TouchControls!
    #endif

    // MARK: - Time
    private var lastUpdateTime: TimeInterval = 0
    private var timeAccumulator: CGFloat = 0

    // MARK: - Layers
    private let tileLayer   = SKNode()
    private let entityLayer = SKNode()

    // MARK: - Spawn
    private var spawnPoint: CGPoint = .zero

    // MARK: - Setup

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.36, green: 0.64, blue: 1.0, alpha: 1.0)
        scaleMode = .resizeFill
        anchorPoint = .zero

        tileLayer.zPosition = 0
        entityLayer.zPosition = 10
        addChild(tileLayer)
        addChild(entityLayer)

        let cam = SKCameraNode()
        camera = cam
        addChild(cam)

        // Build the selected level via LevelBuilder. It fills the map and
        // calls our spawnGoomba helper for each enemy.
        let ts = GameScene.tileSize
        let levelWidth = LevelBuilder.mapWidth(forLevel: currentLevel)
        map = TileMap(width: levelWidth, height: 15, tileSize: ts)
        let info = LevelBuilder.build(
            level: currentLevel,
            map: map,
            tileSize: ts,
            spawner: { [unowned self] col, row in
                self.spawnGoomba(col: col, row: row)
            })
        spawnPoint     = info.spawnPoint
        flagpoleColumn = info.flagpoleColumn
        renderAllTiles()

        player = Player(position: spawnPoint)
        player.onHeadBonk = { [weak self] col, row in
            self?.handleHeadBonk(col: col, row: row)
        }

        let playerNode = SKSpriteNode(
            color: .red,
            size: CGSize(width: Player.hitboxWidth,
                         height: Player.hitboxHeight))
        playerNode.position = player.position
        playerNode.zPosition = 20
        player.node = playerNode
        entityLayer.addChild(playerNode)

        // Camera follow
        camController = CameraController(
            cameraNode: cam,
            target: player,
            levelBounds: map.worldBounds)

        setupHUD()

        #if os(macOS)
        view.window?.makeFirstResponder(self)
        #endif
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        guard coinLabel != nil else { return }  // not yet set up
        relayoutHUD()
    }

    // MARK: - HUD setup

    private func setupHUD() {
        guard let cam = camera else { return }

        coinLabel = SKLabelNode(text: "Coins: 0")
        coinLabel.fontName  = "Helvetica-Bold"
        coinLabel.fontSize  = 22
        coinLabel.fontColor = .white
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.verticalAlignmentMode   = .top
        coinLabel.zPosition = 1_000
        cam.addChild(coinLabel)

        livesLabel = SKLabelNode(text: "Lives: 3")
        livesLabel.fontName  = "Helvetica-Bold"
        livesLabel.fontSize  = 22
        livesLabel.fontColor = .white
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.verticalAlignmentMode   = .top
        livesLabel.zPosition = 1_000
        cam.addChild(livesLabel)

        // Small pause button (top-right, below lives)
        pauseButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44),
                                   cornerRadius: 6)
        pauseButton.fillColor   = SKColor(white: 0, alpha: 0.5)
        pauseButton.strokeColor = .white
        pauseButton.lineWidth   = 2
        pauseButton.zPosition   = 1_000
        let pauseLabel = SKLabelNode(text: "II")
        pauseLabel.fontName  = "Helvetica-Bold"
        pauseLabel.fontSize  = 22
        pauseLabel.fontColor = .white
        pauseLabel.verticalAlignmentMode   = .center
        pauseLabel.horizontalAlignmentMode = .center
        pauseButton.addChild(pauseLabel)
        cam.addChild(pauseButton)

        #if os(iOS) || os(tvOS)
        touchControls = TouchControls()
        cam.addChild(touchControls)
        #endif

        relayoutHUD()
    }

    private func relayoutHUD() {
        guard let coinLabel = coinLabel else { return }

        // With a camera at the level origin (0, 0 in its own space), the
        // visible region spans (-w/2, -h/2)..(w/2, h/2) in camera space.
        let halfW = size.width  * 0.5
        let halfH = size.height * 0.5

        var topInset: CGFloat = 16
        var leftInset: CGFloat = 16
        var rightInset: CGFloat = 16

        #if os(iOS) || os(tvOS)
        let safeInsets = view?.safeAreaInsets ?? .zero
        topInset  += safeInsets.top
        leftInset += safeInsets.left
        rightInset += safeInsets.right
        touchControls?.layout(sceneSize: size, safeInsets: safeInsets)
        #endif

        coinLabel.position = CGPoint(
            x: -halfW + leftInset,
            y:  halfH - topInset)

        livesLabel.position = CGPoint(
            x:  halfW - rightInset,
            y:  halfH - topInset)

        // Pause button sits just below the lives label.
        pauseButton.position = CGPoint(
            x:  halfW - rightInset - 22,
            y:  halfH - topInset - 55)
    }

    private func updateCoinLabel() {
        coinLabel.text = "Coins: \(coinCount)"
    }

    // MARK: - Tile rendering

    private func renderAllTiles() {
        for row in 0..<map.height {
            for col in 0..<map.width {
                let kind = map.tile(at: col, row: row)
                if kind != .empty {
                    addTileNode(kind: kind, col: col, row: row)
                }
            }
        }
    }

    private func addTileNode(kind: TileKind, col: Int, row: Int) {
        let key = row * map.width + col
        let ts = GameScene.tileSize
        let cx = CGFloat(col) * ts + ts * 0.5
        let cy = CGFloat(row) * ts + ts * 0.5

        let node: SKNode
        switch kind {
        case .empty:
            return
        case .coin:
            // Small yellow circle, ~40% of tile size.
            let shape = SKShapeNode(circleOfRadius: ts * 0.2)
            shape.fillColor   = SKColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1.0)
            shape.strokeColor = SKColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0)
            shape.lineWidth   = 1.5
            shape.position    = CGPoint(x: cx, y: cy)
            shape.zPosition   = 1
            node = shape
        default:
            let color: SKColor
            switch kind {
            case .solid:     color = SKColor(white: 0.35, alpha: 1)
            case .brick:     color = SKColor(red: 0.72, green: 0.35, blue: 0.15, alpha: 1)
            case .question:  color = SKColor(red: 0.95, green: 0.75, blue: 0.1,  alpha: 1)
            case .oneWay:    color = SKColor(red: 0.6,  green: 0.4,  blue: 0.2,  alpha: 0.9)
            case .usedBlock: color = SKColor(white: 0.20, alpha: 1)
            default:         color = .magenta  // unreachable
            }
            let sprite = SKSpriteNode(
                color: color,
                size: CGSize(width: ts - 1, height: ts - 1))
            sprite.position  = CGPoint(x: cx, y: cy)
            sprite.zPosition = 0
            node = sprite
        }
        tileLayer.addChild(node)
        tileNodes[key] = node
    }

    private func replaceTileNode(kind: TileKind, col: Int, row: Int) {
        let key = row * map.width + col
        tileNodes[key]?.removeFromParent()
        tileNodes.removeValue(forKey: key)
        if kind != .empty {
            addTileNode(kind: kind, col: col, row: row)
        }
    }

    // MARK: - Goombas

    private func spawnGoomba(col: Int, row: Int) {
        let ts = GameScene.tileSize
        let pos = CGPoint(
            x: CGFloat(col) * ts + ts * 0.5,
            y: CGFloat(row) * ts + ts * 0.5)
        let g = Goomba(position: pos)

        let node = SKSpriteNode(
            color: .brown,
            size: CGSize(width: Goomba.hitboxWidth,
                         height: Goomba.hitboxHeight))
        node.position = pos
        node.zPosition = 15
        g.node = node
        entityLayer.addChild(node)
        enemies.append(g)
    }

    // MARK: - Game loop

    public override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let raw = CGFloat(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        timeAccumulator += min(raw, 0.1)

        while timeAccumulator >= GameScene.fixedTimeStep {
            step(dt: GameScene.fixedTimeStep)
            timeAccumulator -= GameScene.fixedTimeStep
        }

        camController.update(viewSize: size)
    }

    private func step(dt: CGFloat) {
        // Gameplay only advances during the `.playing` state. Pause, death
        // animation, game over, and the level-complete transition all freeze
        // the simulation.
        guard state == .playing else { return }

        gameTime += dt

        // Pull touch-control state into the shared InputState.
        #if os(iOS) || os(tvOS)
        input.leftHeld  = touchControls.leftHeld
        input.rightHeld = touchControls.rightHeld
        input.jumpHeld  = touchControls.jumpHeld
        input.runHeld   = touchControls.runHeld
        if touchControls.consumeJumpPress() {
            input.jumpPressedThisFrame = true
        }
        #endif

        player.update(dt: dt, input: input, map: map)
        input.jumpPressedThisFrame = false

        for enemy in enemies {
            enemy.update(dt: dt, map: map)
        }

        collectOverlappingCoins()
        handleEnemyCollisions()

        if player.justLanded {
            playLandingSquash()
        }

        // Fell into a pit — trigger death sequence.
        if player.position.y < -40 && state == .playing {
            startDeath()
            return
        }

        // Reached the flagpole → level complete. The flagpole is a solid
        // column, so wall push-out clamps `hitbox.maxX` to exactly the
        // column's left edge on the frame the player touches it.
        let triggerX = CGFloat(flagpoleColumn) * GameScene.tileSize
        if player.hitbox.maxX >= triggerX && state == .playing {
            completeLevel()
        }
    }

    // MARK: - Coin pickups

    private func collectOverlappingCoins() {
        let box = player.hitbox
        let minCol = max(0, map.column(forX: box.minX))
        let maxCol = min(map.width  - 1, map.column(forX: box.maxX - 0.001))
        let minRow = max(0, map.row(forY: box.minY))
        let maxRow = min(map.height - 1, map.row(forY: box.maxY - 0.001))
        guard minCol <= maxCol, minRow <= maxRow else { return }

        for col in minCol...maxCol {
            for row in minRow...maxRow {
                if map.tile(at: col, row: row) == .coin {
                    collectCoin(col: col, row: row)
                }
            }
        }
    }

    private func collectCoin(col: Int, row: Int) {
        map.setTile(.empty, at: col, row: row)
        coinCount += 1
        updateCoinLabel()

        let key = row * map.width + col
        if let node = tileNodes.removeValue(forKey: key) {
            let pop = SKAction.group([
                SKAction.scale(to: 1.8, duration: 0.15),
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.moveBy(x: 0, y: 18, duration: 0.15)
            ])
            node.run(SKAction.sequence([pop, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Question block hits

    private func handleHeadBonk(col: Int, row: Int) {
        guard map.tile(at: col, row: row) == .question else { return }

        // Swap to a used block visually and logically.
        map.setTile(.usedBlock, at: col, row: row)
        replaceTileNode(kind: .usedBlock, col: col, row: row)

        // Pop a coin out of the top of the block.
        coinCount += 1
        updateCoinLabel()
        spawnCoinPopup(col: col, row: row)
    }

    private func spawnCoinPopup(col: Int, row: Int) {
        let ts = GameScene.tileSize
        let startX = CGFloat(col) * ts + ts * 0.5
        let startY = CGFloat(row) * ts + ts        // top edge of block

        let coin = SKShapeNode(circleOfRadius: ts * 0.2)
        coin.fillColor   = SKColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1.0)
        coin.strokeColor = SKColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0)
        coin.lineWidth   = 1.5
        coin.position    = CGPoint(x: startX, y: startY + 4)
        coin.zPosition   = 5
        tileLayer.addChild(coin)

        let rise    = SKAction.moveBy(x: 0, y: 30, duration: 0.20)
        rise.timingMode = .easeOut
        let fade    = SKAction.fadeOut(withDuration: 0.12)
        let remove  = SKAction.removeFromParent()
        coin.run(SKAction.sequence([rise, fade, remove]))
    }

    // MARK: - Enemy collisions

    private func handleEnemyCollisions() {
        let playerBox = player.hitbox
        for enemy in enemies where enemy.alive {
            guard playerBox.intersects(enemy.hitbox) else { continue }

            let playerBottom = playerBox.minY
            let enemyTop     = enemy.hitbox.maxY
            let stompThreshold: CGFloat = 6

            let descending = player.velocity.dy < 0
            let fromAbove  = playerBottom >= enemyTop - stompThreshold

            if descending && fromAbove {
                enemy.squash()
                player.bounce(velocity: 440, jumpHeld: input.jumpHeld)
            } else {
                startDeath()
                return
            }
        }
    }

    private func playLandingSquash() {
        guard let n = player.node else { return }
        n.removeAction(forKey: "squash")
        let squash = SKAction.scaleX(to: 1.25, y: 0.75, duration: 0.05)
        let over   = SKAction.scaleX(to: 0.95, y: 1.05, duration: 0.08)
        let settle = SKAction.scaleX(to: 1.00, y: 1.00, duration: 0.06)
        n.run(SKAction.sequence([squash, over, settle]), withKey: "squash")
    }

    // MARK: - Death + respawn

    private func updateLivesLabel() {
        livesLabel.text = "Lives: \(max(0, lives))"
    }

    /// Enter the death sequence: freeze briefly, bounce the sprite up, let
    /// it fall offscreen, fade to black, then either respawn or show the
    /// game over screen.
    private func startDeath() {
        guard state == .playing else { return }
        state = .dying
        player.velocity = .zero

        guard let n = player.node else {
            finalizeDeath()
            return
        }
        n.removeAllActions()

        let freeze = SKAction.wait(forDuration: 0.2)
        let bounce = SKAction.moveBy(x: 0, y: 120, duration: 0.35)
        bounce.timingMode = .easeOut
        let fall = SKAction.moveBy(x: 0, y: -600, duration: 0.7)
        fall.timingMode = .easeIn
        let done = SKAction.run { [weak self] in self?.finalizeDeath() }
        n.run(SKAction.sequence([freeze, bounce, fall, done]))
    }

    private func finalizeDeath() {
        lives -= 1
        updateLivesLabel()

        // Fade-to-black transition overlay (covers the visible area).
        let halfW = size.width  * 0.5
        let halfH = size.height * 0.5
        let fade = SKShapeNode(rect: CGRect(
            x: -halfW, y: -halfH,
            width: size.width, height: size.height))
        fade.fillColor   = .black
        fade.strokeColor = .clear
        fade.alpha       = 0
        fade.zPosition   = 2_000
        camera?.addChild(fade)

        let fadeIn  = SKAction.fadeAlpha(to: 1, duration: 0.25)
        let hold    = SKAction.wait(forDuration: 0.25)
        let act = SKAction.run { [weak self] in
            guard let self = self else { return }
            if self.lives <= 0 {
                self.showGameOver()
            } else {
                self.respawn()
            }
        }
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.35)
        let remove  = SKAction.removeFromParent()
        fade.run(SKAction.sequence([fadeIn, hold, act, fadeOut, remove]))
    }

    private func respawn() {
        player.teleport(to: spawnPoint)
        player.node?.position = spawnPoint
        player.node?.removeAllActions()
        player.node?.setScale(1.0)
        state = .playing
    }

    // MARK: - Level complete

    private func completeLevel() {
        guard state == .playing else { return }
        state = .complete
        guard let view = self.view else { return }
        let scene = LevelCompleteScene(
            size: size,
            level: currentLevel,
            coins: coinCount,
            elapsed: TimeInterval(gameTime))
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.5))
    }

    // MARK: - Pause

    private func pauseGame() {
        guard state == .playing else { return }
        state = .paused
        showPauseOverlay()
    }

    private func resumeGame() {
        guard state == .paused else { return }
        hideOverlay()
        state = .playing
    }

    private func showPauseOverlay() {
        let overlay = makeOverlay(title: "PAUSED", buttons: [
            ("resume",   "RESUME"),
            ("mainMenu", "MAIN MENU")
        ])
        camera?.addChild(overlay)
        activeOverlay = overlay
    }

    private func showGameOver() {
        state = .gameOver
        let overlay = makeOverlay(title: "GAME OVER", buttons: [
            ("retry",    "RETRY"),
            ("mainMenu", "MAIN MENU")
        ])
        camera?.addChild(overlay)
        activeOverlay = overlay
    }

    private func hideOverlay() {
        activeOverlay?.removeFromParent()
        activeOverlay = nil
        overlayButtons.removeAll()
    }

    /// Build a modal overlay pinned to the camera. Returns the root node and
    /// populates `overlayButtons` with hit-test entries for each button.
    private func makeOverlay(title: String,
                             buttons: [(name: String, label: String)]) -> SKNode {
        overlayButtons.removeAll()

        let root = SKNode()
        root.zPosition = 1_500

        // Full-screen dark backing.
        let halfW = size.width  * 0.5
        let halfH = size.height * 0.5
        let bg = SKShapeNode(rect: CGRect(
            x: -halfW, y: -halfH, width: size.width, height: size.height))
        bg.fillColor   = SKColor(white: 0, alpha: 0.7)
        bg.strokeColor = .clear
        bg.zPosition   = 0
        root.addChild(bg)

        let titleLabel = SKLabelNode(text: title)
        titleLabel.fontName  = "Helvetica-Bold"
        titleLabel.fontSize  = 48
        titleLabel.fontColor = .white
        titleLabel.position  = CGPoint(x: 0, y: 80)
        titleLabel.zPosition = 1
        root.addChild(titleLabel)

        let buttonSize = CGSize(width: 240, height: 56)
        for (i, entry) in buttons.enumerated() {
            let y: CGFloat = CGFloat(-20 - i * 75)
            let rect = CGRect(
                x: -buttonSize.width * 0.5,
                y: -buttonSize.height * 0.5,
                width: buttonSize.width,
                height: buttonSize.height)
            let btn = SKShapeNode(rect: rect, cornerRadius: 10)
            btn.fillColor   = SKColor(white: 0, alpha: 0.55)
            btn.strokeColor = .white
            btn.lineWidth   = 2.5
            btn.position    = CGPoint(x: 0, y: y)
            btn.name        = entry.name
            btn.zPosition   = 1

            let label = SKLabelNode(text: entry.label)
            label.fontName  = "Helvetica-Bold"
            label.fontSize  = 26
            label.fontColor = .white
            label.verticalAlignmentMode   = .center
            label.horizontalAlignmentMode = .center
            btn.addChild(label)

            root.addChild(btn)
            overlayButtons.append((entry.name, btn))
        }
        return root
    }

    /// Attempt to handle a tap on the HUD (overlay buttons first, then the
    /// pause button). Returns `true` if the tap was consumed so the caller
    /// knows to skip world-space routing.
    private func handleHUDTap(atCameraPoint p: CGPoint) -> Bool {
        // Overlay buttons take priority when one is visible.
        if activeOverlay != nil {
            for (name, node) in overlayButtons where node.contains(p) {
                handleOverlayAction(name: name)
                return true
            }
            // Tap anywhere on an active overlay is consumed, even if it
            // misses a button — prevents the underlying touch controls
            // from receiving input while paused / game over.
            return true
        }

        // Pause button (only while playing).
        if state == .playing, pauseButton.contains(p) {
            pauseGame()
            return true
        }
        return false
    }

    private func handleOverlayAction(name: String) {
        switch name {
        case "resume":
            resumeGame()
        case "retry":
            guard let view = self.view else { return }
            let game = GameScene(size: size, level: currentLevel)
            game.scaleMode = .resizeFill
            view.presentScene(game, transition: .fade(withDuration: 0.4))
        case "mainMenu":
            guard let view = self.view else { return }
            let menu = MainMenuScene(size: size)
            menu.scaleMode = .resizeFill
            view.presentScene(menu, transition: .fade(withDuration: 0.4))
        default:
            break
        }
    }

    // MARK: - Input: iOS touches

    #if os(iOS) || os(tvOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let cam = camera else { return }
        for touch in touches {
            let camPoint = touch.location(in: cam)
            if handleHUDTap(atCameraPoint: camPoint) { continue }
            if state == .playing {
                touchControls.touchBegan(touch)
            }
        }
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .playing else { return }
        for touch in touches { touchControls.touchMoved(touch) }
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { touchControls.touchEnded(touch) }
    }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { touchControls.touchEnded(touch) }
    }
    #endif

    // MARK: - Input: macOS keyboard

    #if os(macOS)
    public override var acceptsFirstResponder: Bool { true }

    public override func mouseDown(with event: NSEvent) {
        guard let cam = camera else { return }
        let camPoint = event.location(in: cam)
        _ = handleHUDTap(atCameraPoint: camPoint)
    }

    public override func keyDown(with event: NSEvent) {
        if event.isARepeat { return }
        switch event.keyCode {
        case 123: input.leftHeld  = true
        case 124: input.rightHeld = true
        case 49:
            if !input.jumpHeld { input.jumpPressedThisFrame = true }
            input.jumpHeld = true
        case 8:   input.runHeld = true
        default: break
        }
    }

    public override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 123: input.leftHeld  = false
        case 124: input.rightHeld = false
        case 49:  input.jumpHeld  = false
        case 8:   input.runHeld   = false
        default: break
        }
    }
    #endif
}
