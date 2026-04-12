import SpriteKit

/// Mario-style player controller.
///
/// Uses a hand-rolled update loop (no `SKPhysicsBody`) with:
///   * Acceleration-based horizontal movement and doubled "skid" deceleration
///   * Two-phase gravity (weak while rising + jump held, strong otherwise)
///   * Variable jump height via gravity suppression
///   * Run-speed-dependent jump velocity
///   * Coyote time and jump buffering for forgiveness
///   * Split-axis AABB collision against a `TileMap`
///
/// All constants are in points and seconds to stay framerate-independent.
final class Player {

    // MARK: - Tunables
    //
    // These are tuned for a 32-point tile size. Scaling them up from the
    // original 16-point values produced movement that feels appropriate
    // on a phone screen.

    // Horizontal movement
    static let maxWalkSpeed: CGFloat = 200.0
    static let maxRunSpeed:  CGFloat = 350.0
    static let groundAccel:  CGFloat = 900.0
    static let groundDecel:  CGFloat = 900.0
    static let skidDecel:    CGFloat = 1800.0  // doubled when reversing on ground
    static let airAccel:     CGFloat = 900.0
    // Note: there is intentionally NO air friction — airborne velocity persists.

    // Jump / gravity
    static let jumpVelocityWalk: CGFloat = 680.0
    static let jumpVelocityRun:  CGFloat = 750.0
    static let risingGravity:    CGFloat = -900.0   // while rising AND jump held
    static let fallingGravity:   CGFloat = -3000.0  // ~3.3x stronger
    static let maxFallSpeed:     CGFloat = -800.0   // terminal velocity

    // Forgiveness windows (seconds)
    static let coyoteWindow:     CGFloat = 0.10     // ~6 frames @ 60 fps
    static let jumpBufferWindow: CGFloat = 0.10

    // Collision box — intentionally smaller than the visual sprite
    static let hitboxWidth:  CGFloat = 24.0
    static let hitboxHeight: CGFloat = 32.0

    // MARK: - State

    /// World position of the hitbox *center*.
    var position: CGPoint
    var velocity: CGVector = .zero
    var facingRight: Bool  = true
    private(set) var isOnGround: Bool = false
    private(set) var justLanded: Bool = false

    private var coyoteTimer: CGFloat = 0
    private var jumpBufferTimer: CGFloat = 0

    /// Tracks whether the currently-airborne jump is "still alive" — i.e.,
    /// the jump button has been held continuously since the jump started.
    /// Releasing the button ends variable-gravity mode and the player falls.
    private var jumpHeldFromLaunch: Bool = false

    /// Optional sprite node kept in sync with `position`.
    weak var node: SKSpriteNode?

    /// Called whenever the player bonks a solid tile from below. The scene
    /// uses this to react to question-block hits (coin pop, etc).
    var onHeadBonk: ((_ col: Int, _ row: Int) -> Void)?

    init(position: CGPoint) {
        self.position = position
    }

    // MARK: - Geometry

    var hitbox: AABB {
        let hw = Player.hitboxWidth  * 0.5
        let hh = Player.hitboxHeight * 0.5
        return AABB(minX: position.x - hw, minY: position.y - hh,
                    maxX: position.x + hw, maxY: position.y + hh)
    }

    // MARK: - Main update

    /// Run one fixed physics step.
    func update(dt: CGFloat, input: InputState, map: TileMap) {
        justLanded = false
        let prevGrounded = isOnGround

        // --- 1. Timers ---------------------------------------------------
        if input.jumpPressedThisFrame {
            jumpBufferTimer = Player.jumpBufferWindow
        } else {
            jumpBufferTimer = max(0, jumpBufferTimer - dt)
        }
        coyoteTimer = max(0, coyoteTimer - dt)

        // --- 2. Jump trigger --------------------------------------------
        // A jump fires when (a) the buffer is still armed and (b) we're
        // either on the ground or still within the coyote window.
        let canJump = isOnGround || coyoteTimer > 0
        if canJump && jumpBufferTimer > 0 {
            let runJump = abs(velocity.dx) > Player.maxWalkSpeed
            velocity.dy = runJump ? Player.jumpVelocityRun
                                  : Player.jumpVelocityWalk
            isOnGround = false
            coyoteTimer = 0
            jumpBufferTimer = 0
            jumpHeldFromLaunch = true
        }

        // Releasing the button ends the variable-height ascent.
        if !input.jumpHeld {
            jumpHeldFromLaunch = false
        }

        // --- 3. Horizontal input ----------------------------------------
        let h = input.horizontal
        let maxSpeed = input.runHeld ? Player.maxRunSpeed : Player.maxWalkSpeed

        if isOnGround {
            if h != 0 {
                // Skid: when the requested direction opposes current motion,
                // acceleration is effectively doubled.
                let reversing = h * velocity.dx < 0
                let accel = reversing ? Player.skidDecel : Player.groundAccel
                velocity.dx += h * accel * dt
                facingRight = h > 0
            } else {
                velocity.dx = approach(velocity.dx, 0,
                                       Player.groundDecel * dt)
            }
        } else {
            // Air control: same acceleration as ground, but no friction.
            if h != 0 {
                velocity.dx += h * Player.airAccel * dt
                facingRight = h > 0
            }
        }
        velocity.dx = clamp(velocity.dx, -maxSpeed, maxSpeed)

        // --- 4. Gravity (two-phase) -------------------------------------
        // Weak gravity only while *rising* and *still holding the button*
        // since the jump was initiated. Everything else uses strong gravity.
        let gravity: CGFloat
        if velocity.dy > 0 && jumpHeldFromLaunch {
            gravity = Player.risingGravity
        } else {
            gravity = Player.fallingGravity
        }
        velocity.dy += gravity * dt
        velocity.dy = max(velocity.dy, Player.maxFallSpeed)

        // --- 5. Integrate & collide (split axes) ------------------------
        moveX(velocity.dx * dt, in: map)
        moveY(velocity.dy * dt, in: map)

        // --- 6. Post-move state -----------------------------------------
        if !prevGrounded && isOnGround {
            justLanded = true
            jumpHeldFromLaunch = false
        }
        if prevGrounded && !isOnGround && velocity.dy <= 0 {
            // Walked off a ledge — arm the coyote window.
            coyoteTimer = Player.coyoteWindow
        }

        // --- 7. Update visual -------------------------------------------
        node?.position = position
        if let n = node {
            let mag = abs(n.xScale)
            n.xScale = facingRight ? mag : -mag
        }
    }

    /// Apply an upward bounce (e.g., after stomping an enemy). If the jump
    /// button is currently held, variable-gravity mode re-engages so holding
    /// the button produces a higher bounce — matching SMB convention.
    func bounce(velocity upward: CGFloat, jumpHeld: Bool) {
        self.velocity.dy = upward
        self.jumpHeldFromLaunch = jumpHeld
        self.isOnGround = false
    }

    /// Teleport the player (e.g., for respawn). Clears motion/jump state.
    func teleport(to point: CGPoint) {
        position = point
        velocity = .zero
        coyoteTimer = 0
        jumpBufferTimer = 0
        jumpHeldFromLaunch = false
        isOnGround = false
    }

    // MARK: - Collision resolution

    /// Horizontal sweep-and-push. Moves by `dx`, then pushes out of any
    /// overlapping solid tiles along the X axis only. Zeroes `velocity.dx`
    /// on a collision.
    private func moveX(_ dx: CGFloat, in map: TileMap) {
        position.x += dx
        let box = hitbox

        // Slight Y-inset prevents the hitbox from catching on floor / ceiling
        // tile seams while sliding along them.
        let inset: CGFloat = 1.0
        let minCol = max(0, map.column(forX: box.minX))
        let maxCol = min(map.width  - 1, map.column(forX: box.maxX - 0.001))
        let minRow = max(0, map.row(forY: box.minY + inset))
        let maxRow = min(map.height - 1, map.row(forY: box.maxY - inset))
        guard minCol <= maxCol, minRow <= maxRow else { return }

        var push: CGFloat = 0
        for col in minCol...maxCol {
            for row in minRow...maxRow {
                guard map.isSolid(at: col, row: row) else { continue }
                let tile = map.tileRect(col: col, row: row)
                if dx > 0 {
                    push = max(push, box.maxX - tile.minX)
                } else if dx < 0 {
                    push = max(push, tile.maxX - box.minX)
                }
            }
        }

        if push > 0 {
            position.x += (dx > 0 ? -push : push)
            velocity.dx = 0
        }
    }

    /// Vertical sweep-and-push. Handles one-way platforms and landing flag.
    private func moveY(_ dy: CGFloat, in map: TileMap) {
        let previousBottom = hitbox.minY
        position.y += dy
        let box = hitbox

        let inset: CGFloat = 1.0
        let minCol = max(0, map.column(forX: box.minX + inset))
        let maxCol = min(map.width  - 1, map.column(forX: box.maxX - inset))
        let minRow = max(0, map.row(forY: box.minY))
        let maxRow = min(map.height - 1, map.row(forY: box.maxY - 0.001))
        guard minCol <= maxCol, minRow <= maxRow else {
            isOnGround = false
            return
        }

        var push: CGFloat = 0
        var landed = false
        var bonkCol: Int? = nil
        var bonkRow: Int? = nil

        for col in minCol...maxCol {
            for row in minRow...maxRow {
                let kind = map.tile(at: col, row: row)
                guard kind != .empty else { continue }
                // Non-solid decorative tiles (e.g. coins) never block motion.
                if !map.isSolid(at: col, row: row) && kind != .oneWay { continue }
                let tile = map.tileRect(col: col, row: row)

                // One-way platforms: only collide if the player was at or
                // above the tile's top edge *last frame* AND is currently
                // descending. Checking `previousBottom` rather than velocity
                // alone avoids the classic "fall through after jumping up
                // past the platform" bug.
                if kind == .oneWay {
                    if dy <= 0 && previousBottom >= tile.maxY - 0.001 {
                        let overlap = tile.maxY - box.minY
                        if overlap > push {
                            push = overlap
                            landed = true
                        }
                    }
                    continue
                }

                // Regular solid.
                if dy < 0 {
                    let overlap = tile.maxY - box.minY
                    if overlap > push {
                        push = overlap
                        landed = true
                    }
                } else if dy > 0 {
                    let overlap = box.maxY - tile.minY
                    if overlap > push {
                        push = overlap
                        landed = false
                        bonkCol = col
                        bonkRow = row
                    }
                }
            }
        }

        if push > 0 {
            if dy < 0 {
                position.y += push
            } else if dy > 0 {
                position.y -= push
                if let c = bonkCol, let r = bonkRow {
                    onHeadBonk?(c, r)
                }
            }
            velocity.dy = 0
            isOnGround = landed
        } else {
            isOnGround = false
        }
    }
}
