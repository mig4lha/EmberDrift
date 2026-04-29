import SpriteKit

final class XPOrbNode: SKNode {
    private let body: SKShapeNode
    var xpValue: Int = 0

    init(radius: CGFloat = 6) {
        self.body = SKShapeNode(circleOfRadius: radius)
        super.init()

        body.fillColor = .systemYellow
        body.strokeColor = .clear
        addChild(body)

        let physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody.affectedByGravity = false
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = PhysicsCategory.xpOrb
        physicsBody.collisionBitMask = PhysicsCategory.none
        physicsBody.contactTestBitMask = PhysicsCategory.player
        self.physicsBody = physicsBody
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset(xpValue: Int) {
        self.xpValue = xpValue
        isHidden = false
        physicsBody?.categoryBitMask = PhysicsCategory.xpOrb
        physicsBody?.contactTestBitMask = PhysicsCategory.player
    }
}

