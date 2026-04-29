import SpriteKit

final class BossNode: SKNode {
    private let body: SKShapeNode
    private(set) var maxHP: CGFloat
    private(set) var hp: CGFloat
    var moveSpeed: CGFloat
    var contactDamage: CGFloat

    init(maxHP: CGFloat, moveSpeed: CGFloat, contactDamage: CGFloat) {
        self.maxHP = maxHP
        self.hp = maxHP
        self.moveSpeed = moveSpeed
        self.contactDamage = contactDamage
        self.body = SKShapeNode(circleOfRadius: 42)
        super.init()

        body.fillColor = .systemPurple
        body.strokeColor = .clear
        addChild(body)

        let physicsBody = SKPhysicsBody(circleOfRadius: 42)
        physicsBody.affectedByGravity = false
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = PhysicsCategory.boss
        physicsBody.collisionBitMask = PhysicsCategory.none
        physicsBody.contactTestBitMask = PhysicsCategory.player
        self.physicsBody = physicsBody
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyDamage(_ amount: CGFloat) {
        hp = max(0, hp - amount)
    }
}

