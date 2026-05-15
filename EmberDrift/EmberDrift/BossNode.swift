import SpriteKit

final class BossNode: SKNode {
    var maxHP: CGFloat
    var hp: CGFloat
    var moveSpeed: CGFloat
    var contactDamage: CGFloat

    private let radius: CGFloat
    private let sprite: SKSpriteNode
    private let fallbackShape: SKShapeNode

    init(radius: CGFloat, maxHP: CGFloat, moveSpeed: CGFloat, contactDamage: CGFloat) {
        self.radius = radius
        self.maxHP = maxHP
        self.hp = maxHP
        self.moveSpeed = moveSpeed
        self.contactDamage = contactDamage
        self.sprite = SKSpriteNode(color: .clear, size: CGSize(width: radius * 2, height: radius * 2))
        self.fallbackShape = SKShapeNode(circleOfRadius: radius)
        super.init()

        zPosition = 12

        if let tex = GameAssets.texture(GameAssets.ImageName.bossVoidColossus) {
            sprite.texture = tex
            sprite.size = CGSize(width: radius * 2.8, height: radius * 2.8)
            addChild(sprite)
        } else {
            fallbackShape.fillColor = SKColor(white: 0.85, alpha: 1)
            fallbackShape.strokeColor = .clear
            addChild(fallbackShape)
        }

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.isDynamic = true
        body.linearDamping = 0
        body.friction = 0
        body.restitution = 0
        body.mass = 48
        body.categoryBitMask = RunScene.Physics.boss
        body.collisionBitMask = RunScene.Physics.enemy
        body.contactTestBitMask = RunScene.Physics.player
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult
    func applyDamage(_ amount: CGFloat) -> Bool {
        guard amount > 0 else { return false }
        hp = max(0, hp - amount)
        let flashRadius = sprite.parent != nil ? radius * 1.2 : radius
        showDamageFlash(radius: flashRadius)
        return hp <= 0
    }
}

