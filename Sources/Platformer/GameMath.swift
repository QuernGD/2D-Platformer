import CoreGraphics

// MARK: - Scalar helpers

@inline(__always)
func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
    return min(max(value, minValue), maxValue)
}

/// Move `current` toward `target` by at most `delta`, without overshooting.
/// Used for friction/deceleration curves.
@inline(__always)
func approach(_ current: CGFloat, _ target: CGFloat, _ delta: CGFloat) -> CGFloat {
    if current < target {
        return min(current + delta, target)
    } else {
        return max(current - delta, target)
    }
}

@inline(__always)
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    return a + (b - a) * t
}

// MARK: - Axis-aligned bounding box

/// Lightweight AABB used by the custom physics code.
/// SpriteKit's CGRect would work too, but AABB makes intent explicit.
struct AABB {
    var minX: CGFloat
    var minY: CGFloat
    var maxX: CGFloat
    var maxY: CGFloat

    var width: CGFloat { maxX - minX }
    var height: CGFloat { maxY - minY }
    var centerX: CGFloat { (minX + maxX) * 0.5 }
    var centerY: CGFloat { (minY + maxY) * 0.5 }

    func intersects(_ other: AABB) -> Bool {
        return minX < other.maxX && maxX > other.minX &&
               minY < other.maxY && maxY > other.minY
    }
}
