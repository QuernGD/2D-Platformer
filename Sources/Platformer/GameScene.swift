import SpriteKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Main scene that wires the custom physics up to SpriteKit's rendering and
/// event loop. The key integration choice: run the game at a *fixed*
/// timestep via an accumulator, so physics stay deterministic regardless of
/// the device's actual refresh rate.
public final class GameScene: SKScene {

    // MARK: - Constants
    public static let tileSize:      CGFloat = 16
    public static let fixedTimeStep: CGFloat = 1.0 / 60.0

    // MARK: - Game state
    private var map: TileMap!
    private var player: Player!
    private var enemies: [Goomba] = []
    private var camController: CameraController!

    private var input = InputState()
    private var lastUpdateTime: TimeInterval = 0
    private var timeAccumulator: CGFloat = 0

    // Visual layers
    private let tileLayer   = SKNode()
    private let entityLayer = SKNode()

    // Spawn point for respawning
    private var spawnPoint: CGPoint = .zero

    // MARK: - Setup

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.36, green: 0.64, blue: 1.0, alpha: 1.0)
        scaleMode = .resizeFill
        anchorPoint = .zero

        addChild(tileLayer)
        addChild(entityLayer)

        let cam = SKCameraNode()
        camera = cam
        addChild(cam)

        buildTestLevel()

        // Player — spawn on top of the floor tiles
        spawnPoint = CGPoint(x: 3.5 * GameScene.tileSize,
                             y: 5.0 * GameScene.tileSize)
        player = Player(position: spawnPoint)

        let playerNode = SKSpriteNode(
            color: .red,
            size: CGSize(width: Player.hitboxWidth,
                         height: Player.hitboxHeight))
        playerNode.position = player.position
        player.node = playerNode
        entityLayer.addChild(playerNode)

        // Camera controller
        camController = CameraController(
            cameraNode: cam,
            target: player,
            levelBounds: map.worldBounds)

        // Focus on macOS so keyDown is delivered to the scene.
        #if os(macOS)
        view.window?.makeFirstResponder(self)
        #endif
    }

    // MARK: - Level generation

    private func buildTestLevel() {
        let w = 80, h = 15
        map = TileMap(width: w, height: h, tileSize: GameScene.tileSize)

        // Ground
        for col in 0..<w {
            map.setTile(.solid, at: col, row: 0)
            map.setTile(.solid, at: col, row: 1)
        }

        // Gap (fall hazard)
        for col in 20...22 {
            map.setTile(.empty, at: col, row: 0)
            map.setTile(.empty, at: col, row: 1)
        }

        // Row of bricks with a question block in the middle
        for col in 8...10 {
            map.setTile(.brick, at: col, row: 5)
        }
        map.setTile(.question, at: 9, row: 5)

        // A step with a ceiling for head-bonk testing
        for col in 30...34 { map.setTile(.solid, at: col, row: 2) }
        for col in 31...34 { map.setTile(.solid, at: col, row: 3) }
        for col in 32...33 { map.setTile(.solid, at: col, row: 8) }

        // One-way platform
        for col in 40...44 {
            map.setTile(.oneWay, at: col, row: 6)
        }

        // Tall wall
        for row in 2...9 {
            map.setTile(.solid, at: 60, row: row)
        }

        renderTiles()

        // Goombas
        spawnGoomba(at: CGPoint(
            x: 15 * GameScene.tileSize,
            y:  3 * GameScene.tileSize))
        spawnGoomba(at: CGPoint(
            x: 35 * GameScene.tileSize,
            y:  5 * GameScene.tileSize))
        spawnGoomba(at: CGPoint(
            x: 50 * GameScene.tileSize,
            y:  3 * GameScene.tileSize))
    }

    private func renderTiles() {
        for row in 0..<map.height {
            for col in 0..<map.width {
                let kind = map.tile(at: col, row: row)
                guard kind != .empty else { continue }

                let color: SKColor
                switch kind {
                case .solid:
                    color = SKColor(white: 0.35, alpha: 1)
                case .brick:
                    color = SKColor(red: 0.72, green: 0.35, blue: 0.15, alpha: 1)
                case .question:
                    color = SKColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1)
                case .oneWay:
                    color = SKColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.9)
                case .empty:
                    continue
                }

                let node = SKSpriteNode(
                    color: color,
                    size: CGSize(width: GameScene.tileSize - 1,
                                 height: GameScene.tileSize - 1))
                node.position = CGPoint(
                    x: CGFloat(col) * GameScene.tileSize + GameScene.tileSize * 0.5,
                    y: CGFloat(row) * GameScene.tileSize + GameScene.tileSize * 0.5)
                tileLayer.addChild(node)
            }
        }
    }

    private func spawnGoomba(at position: CGPoint) {
        let g = Goomba(position: position)
        let node = SKSpriteNode(
            color: .brown,
            size: CGSize(width: Goomba.hitboxWidth,
                         height: Goomba.hitboxHeight))
        node.position = position
        g.node = node
        entityLayer.addChild(node)
        enemies.append(g)
    }

    // MARK: - Game loop

    public override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let rawDelta = CGFloat(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        // Clamp against huge pauses (e.g. app was backgrounded) so we don't
        // burn through a thousand physics steps after a resume.
        timeAccumulator += min(rawDelta, 0.1)

        while timeAccumulator >= GameScene.fixedTimeStep {
            step(dt: GameScene.fixedTimeStep)
            timeAccumulator -= GameScene.fixedTimeStep
        }

        camController.update(viewSize: size)
    }

    private func step(dt: CGFloat) {
        player.update(dt: dt, input: input, map: map)
        // Consume the single-frame jump press edge.
        input.jumpPressedThisFrame = false

        for enemy in enemies {
            enemy.update(dt: dt, map: map)
        }

        handlePlayerEnemyCollisions()

        if player.justLanded {
            playLandingSquash()
        }

        // Fell into a pit — respawn.
        if player.position.y < -40 {
            player.teleport(to: spawnPoint)
        }
    }

    private func handlePlayerEnemyCollisions() {
        let playerBox = player.hitbox
        for enemy in enemies where enemy.alive {
            guard playerBox.intersects(enemy.hitbox) else { continue }

            let playerBottom = playerBox.minY
            let enemyTop     = enemy.hitbox.maxY
            let stompThreshold: CGFloat = 4

            // Combined position + velocity stomp test.
            let descending = player.velocity.dy < 0
            let fromAbove  = playerBottom >= enemyTop - stompThreshold

            if descending && fromAbove {
                enemy.squash()
                // Bounce height is higher when the jump button is still held,
                // matching the near-universal modern platformer convention.
                player.bounce(velocity: 320, jumpHeld: input.jumpHeld)
            } else {
                // Side / bottom hit — demo-level "damage" is just respawn.
                player.teleport(to: spawnPoint)
                break
            }
        }
    }

    /// Squash-and-stretch landing juice. Volume-conserving scales, brief
    /// overshoot on the way back to rest.
    private func playLandingSquash() {
        guard let n = player.node else { return }
        n.removeAction(forKey: "squash")
        let squash  = SKAction.scaleX(to: 1.25, y: 0.75, duration: 0.05)
        let over    = SKAction.scaleX(to: 0.95, y: 1.05, duration: 0.08)
        let settle  = SKAction.scaleX(to: 1.00, y: 1.00, duration: 0.06)
        n.run(SKAction.sequence([squash, over, settle]), withKey: "squash")
    }

    // MARK: - Input (macOS)

    // Key mapping (macOS virtual key codes):
    //   Left arrow  (123) → move left
    //   Right arrow (124) → move right
    //   Space        (49) → jump (A button)
    //   C             (8) → run  (B button)
    //
    // On iOS / tvOS, wire on-screen controls or the game controller framework
    // to mutate `input` directly — the physics code doesn't care where the
    // bits come from.

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

    // MARK: - Input (iOS / tvOS)

    // On-screen touch regions (split-screen controls). The screen is divided
    // into three horizontal zones: left third = move left, middle third =
    // move right, right third = jump. Run is implicitly always on.
    //
    // Each active touch is tracked by its zone so multi-touch works (e.g.
    // holding right with one thumb and jumping with the other).

    #if !os(macOS)
    private enum TouchZone { case left, right, jump }
    private var touchZones: [ObjectIdentifier: TouchZone] = [:]

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let zone = zone(for: touch)
            touchZones[ObjectIdentifier(touch)] = zone
        }
        recomputeTouchInput(newPresses: true)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchZones[ObjectIdentifier(touch)] = zone(for: touch)
        }
        recomputeTouchInput(newPresses: false)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchZones.removeValue(forKey: ObjectIdentifier(touch))
        }
        recomputeTouchInput(newPresses: false)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchZones.removeValue(forKey: ObjectIdentifier(touch))
        }
        recomputeTouchInput(newPresses: false)
    }

    private func zone(for touch: UITouch) -> TouchZone {
        let loc = touch.location(in: self)
        let w = size.width
        if loc.x < w / 3 { return .left }
        if loc.x < 2 * w / 3 { return .right }
        return .jump
    }

    private func recomputeTouchInput(newPresses: Bool) {
        let active = Set(touchZones.values)
        input.leftHeld  = active.contains(.left)
        input.rightHeld = active.contains(.right)
        input.runHeld   = true  // always run on mobile

        let jumpNow = active.contains(.jump)
        if newPresses && jumpNow && !input.jumpHeld {
            input.jumpPressedThisFrame = true
        }
        input.jumpHeld = jumpNow
    }
    #endif
}
