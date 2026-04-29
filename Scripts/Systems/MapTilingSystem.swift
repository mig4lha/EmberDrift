import SpriteKit

final class MapTilingSystem {
    private let tileSize: CGFloat
    private var tiles: [[SKSpriteNode]] = []
    private weak var parent: SKNode?

    init(parent: SKNode, tileSize: CGFloat) {
        self.parent = parent
        self.tileSize = tileSize

        // 3x3 grid centered on origin; world-space tiles.
        for y in -1...1 {
            var row: [SKSpriteNode] = []
            for x in -1...1 {
                let tile = SKSpriteNode(color: (x + y).isMultiple(of: 2) ? .darkGray : .black, size: CGSize(width: tileSize, height: tileSize))
                tile.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                tile.zPosition = -100
                tile.position = CGPoint(x: CGFloat(x) * tileSize, y: CGFloat(y) * tileSize)
                parent.addChild(tile)
                row.append(tile)
            }
            tiles.append(row)
        }
    }

    func update(around playerPos: CGPoint) {
        // Ensure the center tile always contains player.
        let centerX = floor(playerPos.x / tileSize) * tileSize
        let centerY = floor(playerPos.y / tileSize) * tileSize

        for yIndex in 0..<3 {
            for xIndex in 0..<3 {
                let tile = tiles[yIndex][xIndex]
                let desiredX = centerX + CGFloat(xIndex - 1) * tileSize
                let desiredY = centerY + CGFloat(yIndex - 1) * tileSize
                tile.position = CGPoint(x: desiredX, y: desiredY)
            }
        }
    }
}

