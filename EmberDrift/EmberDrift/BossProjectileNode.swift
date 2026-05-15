import SpriteKit

/// Large straight-line boss shot (not homing). Roughly player-sized.
final class BossProjectileNode: SKNode {
    static let bodyRadius: CGFloat = 22

    init(
        direction: CGVector,
        speed: CGFloat,
        damage: CGFloat,
        attackCategory: UInt32,
        playerCategory: UInt32
    ) {
        super.init()
        name = "boss_projectile"
        zPosition = 15

        let core = SKShapeNode(circleOfRadius: Self.bodyRadius)
        core.fillColor = SKColor(red: 0.92, green: 0.22, blue: 0.06, alpha: 0.9)
        core.strokeColor = SKColor(red: 1, green: 0.55, blue: 0.18, alpha: 0.95)
        core.lineWidth = 3.5
        core.glowWidth = 2
        addChild(core)

        let body = SKPhysicsBody(circleOfRadius: Self.bodyRadius)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.isDynamic = true
        body.linearDamping = 0
        body.friction = 0
        body.restitution = 0
        body.velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        body.categoryBitMask = attackCategory
        body.collisionBitMask = 0
        body.contactTestBitMask = playerCategory
        physicsBody = body

        let ud = NSMutableDictionary()
        ud["bossAoeDmg"] = NSNumber(value: Double(damage))
        ud["isBossProjectile"] = true
        userData = ud

        run(.sequence([.wait(forDuration: 5.5), .removeFromParent()]))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
