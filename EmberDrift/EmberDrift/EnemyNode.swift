import SpriteKit

final class EnemyNode: SKShapeNode {
    var maxHP: CGFloat
    var hp: CGFloat
    var moveSpeed: CGFloat

    init(radius: CGFloat, maxHP: CGFloat, moveSpeed: CGFloat) {
        self.maxHP = maxHP
        self.hp = maxHP
        self.moveSpeed = moveSpeed
        super.init()

        path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        fillColor = .systemTeal
        strokeColor = .clear
        zPosition = 10

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = RunScene.Physics.enemy
        body.collisionBitMask = RunScene.Physics.none
        body.contactTestBitMask = RunScene.Physics.player
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset(maxHP: CGFloat, moveSpeed: CGFloat) {
        self.maxHP = maxHP
        self.hp = maxHP
        self.moveSpeed = moveSpeed
        isHidden = false
        alpha = 1
    }
}

