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

    // MARK: - World state
    private var map: TileMap!
    private var player: Player!
    private var enemies: [Goomba] = []
    private var camController: CameraController!

    /// Tile visuals keyed by `row * map.width + col`. Used to update tiles
    /// in place when a coin is collected or a question block is hit.
    private var tileNodes: [Int: SKNode] = [:]

    private var coinCount: Int = 0
    private var coinLabel: SKLabelNode!

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

        buildLevel()

        // Player spawns just above the starting ground.
        let ts = GameScene.tileSize
        spawnPoint = CGPoint(x: 3.5 * ts, y: 5.0 * ts)
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

        #if os(iOS) || os(tvOS)
        let safeInsets = view?.safeAreaInsets ?? .zero
        topInset  += safeInsets.top
        leftInset += safeInsets.left
        coinLabel.position = CGPoint(
            x: -halfW + leftInset,
            y:  halfH - topInset)
        touchControls?.layout(sceneSize: size, safeInsets: safeInsets)
        #else
        coinLabel.position = CGPoint(
            x: -halfW + leftInset,
            y:  halfH - topInset)
        #endif
    }

    private func updateCoinLabel() {
        coinLabel.text = "Coins: \(coinCount)"
    }

    // MARK: - Level

    private func buildLevel() {
        let w = 200
        let h = 15
        map = TileMap(width: w, height: h, tileSize: GameScene.tileSize)

        // Fill rows 0-1 with ground for the whole level — we'll carve pits.
        for col in 0..<w {
            map.setTile(.solid, at: col, row: 0)
            map.setTile(.solid, at: col, row: 1)
        }

        // 1. Flat start area (cols 0-5): just ground, nothing fancy.

        // 2. Two goombas in the learning area
        spawnGoomba(col: 8,  row: 3)
        spawnGoomba(col: 11, row: 3)

        // 3. Brick row with question block — cols 12-16 at row 5
        for col in 12...16 { map.setTile(.brick, at: col, row: 5) }
        map.setTile(.question, at: 14, row: 5)

        // Coin arc over the bricks
        for col in 12...16 { map.setTile(.coin, at: col, row: 7) }

        // 4. Staircase up then down (cols 20-28)
        //    Heights: 2, 3, 4, 5, 5, 5, 4, 3, 2
        let stairHeights = [2, 3, 4, 5, 5, 5, 4, 3, 2]
        for (i, top) in stairHeights.enumerated() {
            let col = 20 + i
            for row in 2...(top + 1) {
                map.setTile(.solid, at: col, row: row)
            }
        }
        // Coins arcing over the staircase peak
        for col in 23...25 { map.setTile(.coin, at: col, row: 8) }

        // 5. First pit — 3-tile gap at cols 32-34
        for col in 32...34 {
            map.setTile(.empty, at: col, row: 0)
            map.setTile(.empty, at: col, row: 1)
        }
        // Coins floating over the pit
        for col in 32...34 { map.setTile(.coin, at: col, row: 4) }

        // 6. Three goombas after the gap
        spawnGoomba(col: 36, row: 3)
        spawnGoomba(col: 38, row: 3)
        spawnGoomba(col: 40, row: 3)

        // 7. Floating platforms — mix of solid and one-way (cols 42-56)
        for col in 42...44 { map.setTile(.solid,  at: col, row: 5) }
        for col in 46...48 { map.setTile(.oneWay, at: col, row: 7) }
        for col in 50...52 { map.setTile(.solid,  at: col, row: 6) }
        for col in 54...56 { map.setTile(.oneWay, at: col, row: 8) }
        // Coin arcs above each platform
        for col in 42...44 { map.setTile(.coin, at: col, row: 7) }
        for col in 46...48 { map.setTile(.coin, at: col, row: 9) }
        for col in 50...52 { map.setTile(.coin, at: col, row: 8) }
        for col in 54...56 { map.setTile(.coin, at: col, row: 10) }

        // Goomba on top of the first solid floating platform
        spawnGoomba(col: 43, row: 7)

        // 8. Pipe — 2 wide, 4 tall (cols 58-59, rows 2-5)
        for col in 58...59 {
            for row in 2...5 {
                map.setTile(.solid, at: col, row: row)
            }
        }

        // 9. Running-jump gap — 5 tiles wide at cols 65-69
        for col in 65...69 {
            map.setTile(.empty, at: col, row: 0)
            map.setTile(.empty, at: col, row: 1)
        }
        // Coin arc over the gap (higher in the middle)
        map.setTile(.coin, at: 65, row: 4)
        map.setTile(.coin, at: 66, row: 5)
        map.setTile(.coin, at: 67, row: 5)
        map.setTile(.coin, at: 68, row: 5)
        map.setTile(.coin, at: 69, row: 4)

        // 10. Elevated section with blocks above (cols 75-90)
        for col in 75...90 { map.setTile(.solid, at: col, row: 2) }
        for col in 77...82 { map.setTile(.brick, at: col, row: 6) }
        map.setTile(.question, at: 79, row: 6)
        map.setTile(.question, at: 81, row: 6)
        // Coins under the bricks (where the player can walk along row 3)
        for col in 78...81 { map.setTile(.coin, at: col, row: 4) }
        // Two goombas patrolling the elevated ground
        spawnGoomba(col: 84, row: 4)
        spawnGoomba(col: 88, row: 4)

        // 11. Long precision-jumping pit (cols 100-120)
        for col in 100...120 {
            map.setTile(.empty, at: col, row: 0)
            map.setTile(.empty, at: col, row: 1)
        }
        // Small solid platforms at varying heights
        map.setTile(.solid, at: 103, row: 4)
        map.setTile(.solid, at: 107, row: 5)
        map.setTile(.solid, at: 111, row: 4)
        map.setTile(.solid, at: 115, row: 6)
        map.setTile(.solid, at: 119, row: 4)
        // Coins above each platform
        map.setTile(.coin, at: 103, row: 6)
        map.setTile(.coin, at: 107, row: 7)
        map.setTile(.coin, at: 111, row: 6)
        map.setTile(.coin, at: 115, row: 8)
        map.setTile(.coin, at: 119, row: 6)

        // 12. Stairs up to the flagpole (cols 130-135)
        let finalStairs = [2, 3, 4, 5, 6, 6]
        for (i, top) in finalStairs.enumerated() {
            let col = 130 + i
            for row in 2...(top + 1) {
                map.setTile(.solid, at: col, row: row)
            }
        }
        // Goomba on the top of the stairs
        spawnGoomba(col: 135, row: 8)

        // 13. Flagpole — tall thin column at col 140, rows 2-12
        for row in 2...12 {
            map.setTile(.solid, at: 140, row: row)
        }

        // 14. End-zone flat ground is already in place (rows 0-1 were
        //     filled for the full width). Add a couple more goombas to
        //     reach our ten-enemy minimum and some scattered coins.
        spawnGoomba(col: 155, row: 3)
        spawnGoomba(col: 170, row: 3)
        spawnGoomba(col: 185, row: 3)

        // Decorative coin line along the endzone
        for col in stride(from: 150, through: 195, by: 5) {
            map.setTile(.coin, at: col, row: 4)
        }

        renderAllTiles()
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

        // Fell into a pit — respawn (simple for now).
        if player.position.y < -40 {
            player.teleport(to: spawnPoint)
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
                // Simple death — respawn at spawn point.
                player.teleport(to: spawnPoint)
                break
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

    // MARK: - Input: iOS touches

    #if os(iOS) || os(tvOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { touchControls.touchBegan(touch) }
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
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
