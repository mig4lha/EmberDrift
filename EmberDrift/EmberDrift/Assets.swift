import SpriteKit

enum GameAssets {
    enum ImageName {
        static let playerCinder = "player_cinder"
        static let enemyScuttler = "enemy_scuttler"
        static let enemyBrute = "enemy_brute"
        static let bossVoidColossus = "boss_void_colossus"
        static let tileGround = "tile_ground"
        static let xpOrb = "xp_orb"
    }

    static func texture(_ name: String) -> SKTexture? {
        let texture = SKTexture(imageNamed: name)
        // If the asset doesn't exist, SpriteKit returns a 1x1 placeholder.
        // We treat a 1x1 as "missing" so we can fall back to shapes/colors.
        let size = texture.size()
        return (size.width <= 1.1 && size.height <= 1.1) ? nil : texture
    }
}

