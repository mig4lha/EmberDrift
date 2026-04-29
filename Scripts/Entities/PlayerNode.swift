import SpriteKit

final class PlayerNode: SKNode {
    private let body: SKShapeNode
    private(set) var maxHP: CGFloat
    private(set) var hp: CGFloat

    private(set) var isInvulnerable: Bool = false
    private var invulnRemaining: TimeInterval = 0

    init(maxHP: CGFloat) {
        self.maxHP = maxHP
        self.hp = maxHP
        self.body = SKShapeNode(circleOfRadius: 16)
        super.init()

        body.fillColor = .systemOrange
        body.strokeColor = .clear
        addChild(body)

        let physicsBody = SKPhysicsBody(circleOfRadius: 16)
        physicsBody.affectedByGravity = false
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = PhysicsCategory.player
        physicsBody.collisionBitMask = PhysicsCategory.none
        physicsBody.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.boss | PhysicsCategory.bossAttack
        self.physicsBody = physicsBody
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func tick(dt: TimeInterval) {
        if invulnRemaining > 0 {
            invulnRemaining -= dt
            if invulnRemaining <= 0 {
                invulnRemaining = 0
                isInvulnerable = false
                body.alpha = 1.0
            }
        }
    }

    @discardableResult
    func applyDamage(_ amount: CGFloat) -> Bool {
        guard amount > 0 else { return false }
        guard !isInvulnerable else { return false }
        hp = max(0, hp - amount)
        isInvulnerable = true
        invulnRemaining = 0.5
        body.alpha = 0.55
        return true
    }

    func healToFull() {
        hp = maxHP
    }
}

