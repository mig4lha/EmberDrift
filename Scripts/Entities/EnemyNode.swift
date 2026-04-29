import SpriteKit

enum EnemyKind: String, Codable {
    case scuttler
    case brute
}

final class EnemyNode: SKNode {
    let kind: EnemyKind
    private let body: SKShapeNode

    var maxHP: CGFloat
    var hp: CGFloat
    var moveSpeed: CGFloat
    var contactDamage: CGFloat

    init(kind: EnemyKind, maxHP: CGFloat, moveSpeed: CGFloat, contactDamage: CGFloat, radius: CGFloat) {
        self.kind = kind
        self.maxHP = maxHP
        self.hp = maxHP
        self.moveSpeed = moveSpeed
        self.contactDamage = contactDamage
        self.body = SKShapeNode(circleOfRadius: radius)
        super.init()

        body.fillColor = (kind == .scuttler) ? .systemTeal : .systemRed
        body.strokeColor = .clear
        addChild(body)

        let physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody.affectedByGravity = false
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = PhysicsCategory.enemy
        physicsBody.collisionBitMask = PhysicsCategory.none
        physicsBody.contactTestBitMask = PhysicsCategory.player
        self.physicsBody = physicsBody
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset(maxHP: CGFloat, moveSpeed: CGFloat, contactDamage: CGFloat) {
        self.maxHP = maxHP
        self.hp = maxHP
        self.moveSpeed = moveSpeed
        self.contactDamage = contactDamage
        body.alpha = 1.0
        isHidden = false
    }

    func applyDamage(_ amount: CGFloat) {
        hp = max(0, hp - amount)
    }
}

