import SpriteKit

final class XPOrbNode: SKShapeNode {
    let xpValue: Int

    init(radius: CGFloat = 6, xpValue: Int) {
        self.xpValue = xpValue
        super.init()

        path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        fillColor = .systemYellow
        strokeColor = .clear
        zPosition = 9

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = RunScene.Physics.xpOrb
        body.collisionBitMask = RunScene.Physics.none
        body.contactTestBitMask = RunScene.Physics.player
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

