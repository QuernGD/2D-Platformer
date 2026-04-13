import CoreGraphics

/// Static data describing a single level. Produced by `LevelBuilder.build`
/// and used by `GameScene` to position the player, place the flagpole
/// trigger, and display the level's title.
struct LevelInfo {
    let levelNumber: Int
    let mapWidth: Int
    let spawnPoint: CGPoint
    let flagpoleColumn: Int
    let levelName: String
}

/// Registry of level layouts. Each level is a static function that writes
/// tiles into a pre-allocated `TileMap` and calls the provided `spawner`
/// closure to place goombas.
///
/// To add a new level:
///   1. Bump `maxLevel`
///   2. Add the width to `mapWidth(forLevel:)`
///   3. Add the display name to `name(forLevel:)`
///   4. Add a `buildLevelN` method and route it from `build(level:...)`
enum LevelBuilder {

    /// Highest level currently implemented. The main menu renders this
    /// many buttons and the unlock chain stops here.
    static let maxLevel: Int = 3

    /// Width (in tiles) of the tile map for the given level. `GameScene`
    /// needs this up front so it can allocate the `TileMap` before calling
    /// `build`.
    static func mapWidth(forLevel level: Int) -> Int {
        switch level {
        case 1: return 200
        case 2: return 220
        case 3: return 250
        default: return 200
        }
    }

    /// Display name used in the main menu and level-complete screen.
    static func name(forLevel level: Int) -> String {
        switch level {
        case 1: return "Level 1"
        case 2: return "Level 2 — Underground"
        case 3: return "Level 3 — Sky"
        default: return "Level \(level)"
        }
    }

    /// Fill `map` with the tile layout for `level` and spawn enemies via
    /// `spawner`. Returns the `LevelInfo` that `GameScene` needs to set up
    /// the camera, flagpole trigger, and HUD.
    @discardableResult
    static func build(level: Int,
                      map: TileMap,
                      tileSize: CGFloat,
                      spawner: (Int, Int) -> Void) -> LevelInfo
    {
        switch level {
        case 1:  return buildLevel1(map: map, tileSize: tileSize, spawner: spawner)
        case 2:  return buildLevel2(map: map, tileSize: tileSize, spawner: spawner)
        case 3:  return buildLevel3(map: map, tileSize: tileSize, spawner: spawner)
        default: return buildLevel1(map: map, tileSize: tileSize, spawner: spawner)
        }
    }

    // MARK: - Level 1 (preserved from the original GameScene.buildLevel)

    private static func buildLevel1(map: TileMap,
                                    tileSize ts: CGFloat,
                                    spawner: (Int, Int) -> Void) -> LevelInfo
    {
        let w = map.width

        // Fill rows 0-1 with ground for the whole level — we'll carve pits.
        for col in 0..<w {
            map.setTile(.solid, at: col, row: 0)
            map.setTile(.solid, at: col, row: 1)
        }

        // 1. Flat start area (cols 0-5): just ground, nothing fancy.

        // 2. Two goombas in the learning area
        spawner(8, 3)
        spawner(11, 3)

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
        spawner(36, 3)
        spawner(38, 3)
        spawner(40, 3)

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
        spawner(43, 7)

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
        // Coins under the bricks
        for col in 78...81 { map.setTile(.coin, at: col, row: 4) }
        // Two goombas patrolling the elevated ground
        spawner(84, 4)
        spawner(88, 4)

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

        // 12. Stairs up to the flagpole (cols 183-188)
        let finalStairs = [2, 3, 4, 5, 6, 6]
        for (i, top) in finalStairs.enumerated() {
            let col = 183 + i
            for row in 2...(top + 1) {
                map.setTile(.solid, at: col, row: row)
            }
        }
        // Goomba on the top of the stairs
        spawner(188, 8)

        // 13. Flagpole — tall thin column at col 192, rows 2-12.
        for row in 2...12 {
            map.setTile(.solid, at: 192, row: row)
        }

        // 14. Mid-section extras — goombas + decorative coins between the
        //     precision pit and the final staircase so cols 121-180 aren't
        //     empty.
        spawner(135, 3)
        spawner(150, 3)
        spawner(165, 3)
        spawner(178, 3)

        for col in stride(from: 125, through: 180, by: 5) {
            map.setTile(.coin, at: col, row: 4)
        }

        return LevelInfo(
            levelNumber: 1,
            mapWidth: w,
            spawnPoint: CGPoint(x: 3.5 * ts, y: 5.0 * ts),
            flagpoleColumn: 192,
            levelName: "Level 1")
    }

    // MARK: - Level 2 — Underground

    /// Ceiling-covered cavern with vertical shafts, a two-path upper
    /// walkway, a low-ceiling goomba gauntlet, and a bigger flagpole
    /// staircase. Width 220.
    private static func buildLevel2(map: TileMap,
                                    tileSize ts: CGFloat,
                                    spawner: (Int, Int) -> Void) -> LevelInfo
    {
        let w = map.width   // 220

        // Ground rows 0-1 everywhere — pits carved out below.
        for col in 0..<w {
            map.setTile(.solid, at: col, row: 0)
            map.setTile(.solid, at: col, row: 1)
        }

        // Solid ceiling at row 12 from col 15 to col 200. Shaft gaps and
        // the low-ceiling gauntlet are carved out of this band later.
        for col in 15...200 {
            map.setTile(.solid, at: col, row: 12)
        }

        // 1. Open start area (cols 0-14): no ceiling, two warm-up goombas.
        spawner(8, 3)
        spawner(12, 3)

        // 2. Brick cluster with question block + coin arc (cols 20-24)
        for col in 20...24 { map.setTile(.brick, at: col, row: 5) }
        map.setTile(.question, at: 22, row: 5)
        for col in 20...24 { map.setTile(.coin, at: col, row: 7) }
        spawner(18, 3)
        spawner(30, 3)

        // 3. 4-tile pit with coins across it (cols 36-39)
        for col in 36...39 {
            map.setTile(.empty, at: col, row: 0)
            map.setTile(.empty, at: col, row: 1)
        }
        for col in 36...39 { map.setTile(.coin, at: col, row: 4) }

        // 4. TWO-PATH SPLIT (cols 40-60)
        //    Lower path: flat ground, a couple goombas, fewer coins.
        //    Upper path: hop onto a one-way platform at row 5, then jump
        //    onto a solid walkway at row 8 that runs cols 43-58, studded
        //    with coins the lower path can't reach.
        for col in 40...42 { map.setTile(.oneWay, at: col, row: 5) }
        for col in 43...58 { map.setTile(.solid,  at: col, row: 8) }
        // Upper coins: row 9 sits at the player's chest while standing on
        // the walkway, so they're collected incidentally while walking.
        for col in 43...58 { map.setTile(.coin, at: col, row: 9) }
        // Lower-path ground goombas
        spawner(45, 3)
        spawner(53, 3)
        // Upper-walkway goombas — spawn one row above the walkway so they
        // fall onto it and start patrolling.
        spawner(48, 9)
        spawner(54, 9)

        // 5. Running-jump pit — 5 tiles wide (cols 61-65), coin arc
        for col in 61...65 {
            map.setTile(.empty, at: col, row: 0)
            map.setTile(.empty, at: col, row: 1)
        }
        map.setTile(.coin, at: 61, row: 4)
        map.setTile(.coin, at: 62, row: 5)
        map.setTile(.coin, at: 63, row: 5)
        map.setTile(.coin, at: 64, row: 5)
        map.setTile(.coin, at: 65, row: 4)

        // 6. Vertical shaft section (cols 66-90)
        //    Two gaps in the ceiling at cols 70-72 and cols 80-82. A
        //    helper platform at row 6 boosts the player up through the
        //    first gap — once they're on top of row 12 they can walk
        //    cols 73-79 and collect coins on the ceiling-top, then drop
        //    back down through the second gap.
        for col in 70...72 { map.setTile(.empty, at: col, row: 12) }
        for col in 80...82 { map.setTile(.empty, at: col, row: 12) }
        for col in 67...69 { map.setTile(.solid, at: col, row: 6) }
        // Top-of-ceiling coin line (row 13 sits at player-chest height
        // when standing on the ceiling-top walkway).
        for col in 73...79 { map.setTile(.coin, at: col, row: 13) }
        // Ground-level goombas in the shaft corridor
        spawner(74, 3)
        spawner(78, 3)
        spawner(86, 3)

        // 7. Small pit with stepping-stone platforms (cols 91-95)
        for col in 91...95 {
            map.setTile(.empty, at: col, row: 0)
            map.setTile(.empty, at: col, row: 1)
        }
        map.setTile(.solid, at: 92, row: 4)
        map.setTile(.solid, at: 94, row: 4)
        map.setTile(.coin, at: 92, row: 6)
        map.setTile(.coin, at: 94, row: 6)

        // 8. Layered brick corridor with q-block cluster (cols 100-115)
        //    A continuous brick roof at row 5 with three question blocks
        //    the player bonks from below. Coins sit at row 2 so they're
        //    collected just by walking through the corridor.
        for col in 100...115 { map.setTile(.brick, at: col, row: 5) }
        map.setTile(.question, at: 104, row: 5)
        map.setTile(.question, at: 108, row: 5)
        map.setTile(.question, at: 112, row: 5)
        for col in stride(from: 100, through: 114, by: 2) {
            map.setTile(.coin, at: col, row: 2)
        }
        spawner(98, 3)
        spawner(110, 3)
        spawner(118, 3)
        spawner(125, 3)
        // Lone goomba patrolling the top of the brick roof
        spawner(106, 6)

        // 9. Second two-path split (cols 131-140)
        //    Upper walkway at row 7 with a floating question block above.
        for col in 132...134 { map.setTile(.oneWay, at: col, row: 7) }
        for col in 136...140 { map.setTile(.solid,  at: col, row: 7) }
        for col in 136...140 { map.setTile(.coin,   at: col, row: 8) }
        map.setTile(.question, at: 138, row: 9)

        // 10. LOW-CEILING GAUNTLET (cols 141-180)
        //     Swap the row 12 ceiling for a much tighter row 8 ceiling
        //     and drop six goombas in a line. The low ceiling means the
        //     player can only stomp with short controlled jumps.
        for col in 141...180 {
            map.setTile(.empty, at: col, row: 12)
            map.setTile(.solid, at: col, row: 8)
        }
        spawner(145, 3)
        spawner(150, 3)
        spawner(155, 3)
        spawner(160, 3)
        spawner(165, 3)
        spawner(170, 3)

        // 11. Staircase up to the flagpole (cols 181-187)
        //     Heights 2, 3, 4, 5, 6, 7, 7 — a two-tile landing on top so
        //     the goomba posted there has room to patrol.
        let stairs = [2, 3, 4, 5, 6, 7, 7]
        for (i, top) in stairs.enumerated() {
            let col = 181 + i
            for row in 2...(top + 1) {
                map.setTile(.solid, at: col, row: row)
            }
        }
        spawner(187, 9)

        // 12. Flagpole at col 205, extending up from the ground.
        //     The ceiling ends at col 200 so the flagpole can stand tall
        //     in the open end zone (cols 201-219).
        for row in 2...12 {
            map.setTile(.solid, at: 205, row: row)
        }

        return LevelInfo(
            levelNumber: 2,
            mapWidth: w,
            spawnPoint: CGPoint(x: 3.5 * ts, y: 5.0 * ts),
            flagpoleColumn: 205,
            levelName: "Level 2 — Underground")
    }

    // MARK: - Level 3 — Sky

    /// Bottomless-pit level: solid ground only at the very start and the
    /// very end. Everything in between is floating platforms of varying
    /// sizes and heights. Width 250.
    private static func buildLevel3(map: TileMap,
                                    tileSize ts: CGFloat,
                                    spawner: (Int, Int) -> Void) -> LevelInfo
    {
        let w = map.width   // 250

        // Ground only at cols 0-12 (start) and cols 230-249 (end).
        for col in 0...12 {
            map.setTile(.solid, at: col, row: 0)
            map.setTile(.solid, at: col, row: 1)
        }
        for col in 230..<w {
            map.setTile(.solid, at: col, row: 0)
            map.setTile(.solid, at: col, row: 1)
        }

        // Helper: place a row of solid tiles at a single row.
        func platform(_ cols: ClosedRange<Int>, _ row: Int, oneWay: Bool = false) {
            let kind: TileKind = oneWay ? .oneWay : .solid
            for col in cols { map.setTile(kind, at: col, row: row) }
        }
        func coinRow(_ cols: ClosedRange<Int>, _ row: Int) {
            for col in cols { map.setTile(.coin, at: col, row: row) }
        }

        // 1. Start area (cols 0-12): solid ground, one warm-up goomba
        spawner(7, 3)

        // 2. Comfort section — wide 5-tile platforms, modest gaps (cols 15-35)
        platform(15...19, 2)
        platform(22...26, 2)
        platform(29...33, 3)
        coinRow(15...19, 3)
        coinRow(22...26, 3)
        coinRow(29...33, 4)
        spawner(17, 3)
        spawner(24, 3)

        // 3. Mid-size mixed platforms, some one-way (cols 38-60)
        platform(38...40, 3)
        platform(44...46, 4, oneWay: true)
        platform(50...52, 4)
        platform(56...58, 3)
        // Coin arcs between platforms showing the jump path
        map.setTile(.coin, at: 42, row: 4)
        map.setTile(.coin, at: 43, row: 4)
        map.setTile(.coin, at: 48, row: 5)
        map.setTile(.coin, at: 49, row: 5)
        map.setTile(.coin, at: 54, row: 5)
        map.setTile(.coin, at: 55, row: 5)
        coinRow(38...40, 4)
        coinRow(50...52, 5)
        spawner(39, 4)
        spawner(51, 5)

        // 4. Smaller 2-tile platforms at varying heights (cols 63-90)
        platform(63...64, 4)
        platform(68...69, 5, oneWay: true)
        platform(73...74, 5)
        platform(78...79, 6, oneWay: true)
        platform(83...84, 5)
        platform(88...89, 4)
        coinRow(63...64, 5)
        coinRow(68...69, 6)
        coinRow(73...74, 6)
        coinRow(78...79, 7)
        coinRow(83...84, 6)
        coinRow(88...89, 5)
        spawner(73, 6)
        spawner(83, 6)
        spawner(88, 5)

        // 5. Zigzag 1-tile platforms (cols 93-120)
        //    Gentle up-and-down — alternating row 3 / row 4 so a practiced
        //    walking jump clears each one. No goombas — the platforming is
        //    the challenge.
        let zigRows = [(93, 4), (97, 3), (101, 4), (105, 3),
                       (109, 4), (113, 3), (117, 4)]
        for (col, row) in zigRows {
            map.setTile(.solid, at: col, row: row)
            map.setTile(.coin,  at: col, row: row + 1)
        }

        // 6. Relief section — 3-tile platforms, q-blocks, coin clusters
        //    (cols 123-150)
        platform(123...125, 3)
        platform(129...131, 4)
        map.setTile(.question, at: 130, row: 6)
        platform(135...137, 3)
        platform(141...143, 4)
        map.setTile(.question, at: 142, row: 6)
        platform(147...149, 3)
        coinRow(123...125, 4)
        coinRow(129...131, 5)
        coinRow(135...137, 4)
        coinRow(141...143, 5)
        coinRow(147...149, 4)
        spawner(124, 4)
        spawner(136, 4)

        // 7. Hardest section — 2-tile platforms with 4-col gaps (cols 153-180)
        platform(153...154, 4)
        platform(159...160, 5)
        platform(164...165, 4)
        platform(170...171, 5, oneWay: true)
        platform(175...176, 4)
        coinRow(153...154, 5)
        coinRow(159...160, 6)
        coinRow(164...165, 5)
        coinRow(170...171, 6)
        coinRow(175...176, 5)
        spawner(159, 6)
        spawner(175, 5)

        // 8. Gradually widening approach back to ground (cols 183-225)
        platform(183...186, 3)
        platform(191...194, 3)
        platform(199...202, 3)
        platform(207...211, 2)
        platform(216...221, 2)
        platform(225...229, 2)
        coinRow(183...186, 4)
        coinRow(191...194, 4)
        coinRow(199...202, 4)
        coinRow(207...211, 3)
        coinRow(216...221, 3)
        coinRow(225...229, 3)
        spawner(184, 4)
        spawner(192, 4)
        spawner(217, 3)

        // 9. Staircase + flagpole in the end-zone ground (cols 230-249)
        //    Small staircase cols 231-234 going up, flagpole at col 235.
        let stairs = [2, 3, 4, 5]
        for (i, top) in stairs.enumerated() {
            let col = 231 + i
            for row in 2...(top + 1) {
                map.setTile(.solid, at: col, row: row)
            }
        }
        for row in 2...12 {
            map.setTile(.solid, at: 235, row: row)
        }

        return LevelInfo(
            levelNumber: 3,
            mapWidth: w,
            spawnPoint: CGPoint(x: 3.5 * ts, y: 5.0 * ts),
            flagpoleColumn: 235,
            levelName: "Level 3 — Sky")
    }
}
