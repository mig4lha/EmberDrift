import SpriteKit

enum EnemyKind {
    case scuttler
    case brute
}

final class EnemyNode: SKNode {
    let kind: EnemyKind
    var maxHP: CGFloat
    var hp: CGFloat
    var moveSpeed: CGFloat
    var contactDamage: CGFloat
    private let radius: CGFloat
    private let sprite: SKSpriteNode
    private let fallbackShape: SKShapeNode

    init(kind: EnemyKind, radius: CGFloat, maxHP: CGFloat, moveSpeed: CGFloat, contactDamage: CGFloat) {
        self.kind = kind
        self.maxHP = maxHP
        self.hp = maxHP
        self.moveSpeed = moveSpeed
        self.contactDamage = contactDamage
        self.radius = radius
        self.sprite = SKSpriteNode(color: .clear, size: CGSize(width: radius * 2, height: radius * 2))
        self.fallbackShape = SKShapeNode(circleOfRadius: radius)
        super.init()

        zPosition = 10

        // Sprite if available, otherwise a colored circle.
        let textureName: String = {
            switch kind {
            case .scuttler: return GameAssets.ImageName.enemyScuttler
            case .brute: return GameAssets.ImageName.enemyBrute
            }
        }()

        if let tex = GameAssets.texture(textureName) {
            sprite.texture = tex
            sprite.size = CGSize(width: radius * 2.6, height: radius * 2.6)
            sprite.zPosition = 0
            addChild(sprite)
        } else {
            fallbackShape.fillColor = (kind == .scuttler) ? .systemTeal : .systemRed
            fallbackShape.strokeColor = .clear
            fallbackShape.zPosition = 0
            addChild(fallbackShape)
        }

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = RunScene.Physics.enemy
        body.collisionBitMask = RunScene.Physics.none
        body.contactTestBitMask = RunScene.Physics.player
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset(maxHP: CGFloat, moveSpeed: CGFloat, contactDamage: CGFloat) {
        self.maxHP = maxHP
        self.hp = maxHP
        self.moveSpeed = moveSpeed
        self.contactDamage = contactDamage
        isHidden = false
        alpha = 1
    }
}

