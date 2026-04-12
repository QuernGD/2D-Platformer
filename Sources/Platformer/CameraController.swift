import SpriteKit

/// Smooth follow camera with a dead zone, directional look-ahead, and
/// landing-snap vertical tracking — approximating Super Mario World's feel.
final class CameraController {

    let cameraNode: SKCameraNode
    let target: Player
    var levelBounds: CGRect

    // Tunables
    var deadZoneWidth:   CGFloat = 40
    var lookAhead:       CGFloat = 60
    var horizontalLerp:  CGFloat = 0.12
    var verticalLerp:    CGFloat = 0.15

    /// When true, the camera's X position is clamped so it can only move
    /// rightward — replicating the original SMB's one-way scroll rule.
    var onlyScrollsRight: Bool = false
    private var maxReachedX: CGFloat = -.greatestFiniteMagnitude

    private var verticalTargetY: CGFloat

    init(cameraNode: SKCameraNode, target: Player, levelBounds: CGRect) {
        self.cameraNode = cameraNode
        self.target = target
        self.levelBounds = levelBounds
        self.verticalTargetY = target.position.y
        cameraNode.position = target.position
        self.maxReachedX = target.position.x
    }

    func update(viewSize: CGSize) {
        // --- Horizontal: dead zone + directional look-ahead -------------
        let desiredX = target.position.x +
            (target.facingRight ? lookAhead : -lookAhead)
        let dx = desiredX - cameraNode.position.x
        if abs(dx) > deadZoneWidth {
            cameraNode.position.x += dx * horizontalLerp
        }

        // --- Vertical: snap on landing, otherwise lerp ------------------
        // Keeping the camera stable during jumps (tracking only on landing)
        // was one of SMW's signature polish choices.
        if target.justLanded {
            verticalTargetY = target.position.y
        }
        cameraNode.position.y +=
            (verticalTargetY - cameraNode.position.y) * verticalLerp

        // --- One-way scroll lock ---------------------------------------
        if onlyScrollsRight {
            maxReachedX = max(maxReachedX, cameraNode.position.x)
            cameraNode.position.x = maxReachedX
        }

        // --- Clamp to level bounds --------------------------------------
        let halfW = viewSize.width  * 0.5
        let halfH = viewSize.height * 0.5
        let minX = levelBounds.minX + halfW
        let maxX = levelBounds.maxX - halfW
        let minY = levelBounds.minY + halfH
        let maxY = levelBounds.maxY - halfH

        if minX <= maxX {
            cameraNode.position.x = clamp(cameraNode.position.x, minX, maxX)
        }
        if minY <= maxY {
            cameraNode.position.y = clamp(cameraNode.position.y, minY, maxY)
        }
    }
}
