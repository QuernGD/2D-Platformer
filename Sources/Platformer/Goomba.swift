import SpriteKit

/// Simple walking enemy. Moves in a straight horizontal line, reverses on
/// wall hits, and is subject to the same gravity as the player. Stomping is
/// resolved by `GameScene`, which calls `squash()` on a successful stomp.
final class Goomba {

    // MARK: - Tunables
    static let walkSpeed:    CGFloat = 40.0
    static let hitboxWidth:  CGFloat = 14.0
    static let hitboxHeight: CGFloat = 14.0

    // MARK: - State
    var position: CGPoint
    var velocity: CGVector
    private(set) var alive: Bool = true
    private(set) var squashTimer: CGFloat = 0
    weak var node: SKSpriteNode?

    init(position: CGPoint, movingLeft: Bool = true) {
        self.position = position
        self.velocity = CGVector(
            dx: movingLeft ? -Goomba.walkSpeed : Goomba.walkSpeed,
            dy: 0)
    }

    var hitbox: AABB {
        let hw = Goomba.hitboxWidth  * 0.5
        let hh = Goomba.hitboxHeight * 0.5
        return AABB(minX: position.x - hw, minY: position.y - hh,
                    maxX: position.x + hw, maxY: position.y + hh)
    }

    func update(dt: CGFloat, map: TileMap) {
        if !alive {
            squashTimer = max(0, squashTimer - dt)
            node?.position = position
            return
        }

        // Gravity (use the player's fall gravity for consistency).
        velocity.dy += Player.fallingGravity * dt
        velocity.dy = max(velocity.dy, Player.maxFallSpeed)

        // Horizontal sweep — reverse direction on any wall hit.
        position.x += velocity.dx * dt
        if pushOutHorizontally(in: map) {
            velocity.dx = -velocity.dx
        }

        // Vertical sweep — simple floor snap.
        position.y += velocity.dy * dt
        pushOutVertically(in: map)

        node?.position = position
    }

    /// Kill the enemy from a stomp. Plays a brief squash-and-fade animation.
    func squash() {
        guard alive else { return }
        alive = false
        squashTimer = 0.4
        velocity = .zero

        node?.run(SKAction.sequence([
            SKAction.scaleY(to: 0.3, duration: 0.05),
            SKAction.wait(forDuration: 0.15),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Collision

    private func pushOutHorizontally(in map: TileMap) -> Bool {
        let box = hitbox
        let minCol = max(0, map.column(forX: box.minX))
        let maxCol = min(map.width  - 1, map.column(forX: box.maxX - 0.001))
        let minRow = max(0, map.row(forY: box.minY + 1))
        let maxRow = min(map.height - 1, map.row(forY: box.maxY - 1))
        guard minCol <= maxCol, minRow <= maxRow else { return false }

        var push: CGFloat = 0
        var hit = false
        for col in minCol...maxCol {
            for row in minRow...maxRow {
                guard map.isSolid(at: col, row: row) else { continue }
                let tile = map.tileRect(col: col, row: row)
                if velocity.dx > 0 {
                    push = max(push, box.maxX - tile.minX)
                } else if velocity.dx < 0 {
                    push = max(push, tile.maxX - box.minX)
                }
                hit = true
            }
        }
        if push > 0 {
            position.x += (velocity.dx > 0 ? -push : push)
        }
        return hit
    }

    private func pushOutVertically(in map: TileMap) {
        let box = hitbox
        let minCol = max(0, map.column(forX: box.minX + 1))
        let maxCol = min(map.width  - 1, map.column(forX: box.maxX - 1))
        let minRow = max(0, map.row(forY: box.minY))
        let maxRow = min(map.height - 1, map.row(forY: box.maxY - 0.001))
        guard minCol <= maxCol, minRow <= maxRow else { return }

        var push: CGFloat = 0
        for col in minCol...maxCol {
            for row in minRow...maxRow {
                guard map.isSolid(at: col, row: row) else { continue }
                let tile = map.tileRect(col: col, row: row)
                if velocity.dy < 0 {
                    push = max(push, tile.maxY - box.minY)
                } else if velocity.dy > 0 {
                    push = max(push, box.maxY - tile.minY)
                }
            }
        }
        if push > 0 {
            if velocity.dy < 0 {
                position.y += push
            } else {
                position.y -= push
            }
            velocity.dy = 0
        }
    }
}
