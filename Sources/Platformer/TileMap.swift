import CoreGraphics

/// Tile kinds understood by the collision / rendering code.
enum TileKind: Int {
    case empty    = 0
    case solid    = 1  // regular ground / wall
    case brick    = 2  // breakable (treated as solid)
    case question = 3  // solid, can turn into `empty` when hit from below
    case oneWay   = 4  // jump-through platform (only collides from above)
}

/// Simple integer-grid tile map with AABB collision queries.
///
/// The grid origin is at bottom-left. `(col, row) = (0, 0)` is the bottom-left
/// tile. `tileSize` is the on-screen size in points.
final class TileMap {

    let width: Int
    let height: Int
    let tileSize: CGFloat
    private(set) var tiles: [TileKind]

    init(width: Int, height: Int, tileSize: CGFloat, tiles: [TileKind]? = nil) {
        self.width = width
        self.height = height
        self.tileSize = tileSize
        self.tiles = tiles ?? Array(repeating: .empty, count: width * height)
    }

    // MARK: - Accessors

    func tile(at col: Int, row: Int) -> TileKind {
        guard col >= 0, col < width, row >= 0, row < height else {
            return .empty
        }
        return tiles[row * width + col]
    }

    func setTile(_ kind: TileKind, at col: Int, row: Int) {
        guard col >= 0, col < width, row >= 0, row < height else { return }
        tiles[row * width + col] = kind
    }

    /// True for tiles that block horizontal and vertical movement fully.
    /// One-way platforms are intentionally NOT included here — they are
    /// handled specially in the vertical collision pass.
    func isSolid(at col: Int, row: Int) -> Bool {
        switch tile(at: col, row: row) {
        case .solid, .brick, .question: return true
        case .oneWay, .empty:           return false
        }
    }

    // MARK: - World <-> grid helpers

    func column(forX x: CGFloat) -> Int { Int(floor(x / tileSize)) }
    func row(forY y: CGFloat)    -> Int { Int(floor(y / tileSize)) }

    func tileRect(col: Int, row: Int) -> AABB {
        let x = CGFloat(col) * tileSize
        let y = CGFloat(row) * tileSize
        return AABB(minX: x, minY: y, maxX: x + tileSize, maxY: y + tileSize)
    }

    var worldBounds: CGRect {
        CGRect(x: 0, y: 0,
               width: CGFloat(width) * tileSize,
               height: CGFloat(height) * tileSize)
    }
}
