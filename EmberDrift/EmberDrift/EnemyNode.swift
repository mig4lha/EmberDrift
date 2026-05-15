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
        body.isDynamic = true
        body.linearDamping = 0
        body.friction = 0
        body.restitution = 0
        body.mass = (kind == .brute) ? 1.8 : 1.0
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = RunScene.Physics.enemy
        body.collisionBitMask = RunScene.Physics.enemy | RunScene.Physics.boss
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
        physicsBody?.velocity = .zero
        physicsBody?.isDynamic = true
        childNode(withName: "damageFlashOverlay")?.removeFromParent()
    }

    /// Applies damage, plays hit flash, returns whether HP reached zero.
    @discardableResult
    func applyDamage(_ amount: CGFloat) -> Bool {
        guard amount > 0, !isHidden else { return false }
        hp = max(0, hp - amount)
        let flashRadius = sprite.parent != nil ? radius * 1.35 : radius * 1.15
        showDamageFlash(radius: flashRadius)
        return hp <= 0
    }
}

