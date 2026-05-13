import SpriteKit

final class BossSystem {
    struct PhysicsMasks {
        let bossAttack: UInt32
        let player: UInt32
        let none: UInt32
    }

    private let world: SKNode
    private weak var actionRunner: SKNode?
    private let physics: PhysicsMasks

    private(set) var boss: BossNode?
    private var phase2: Bool = false
    private var stompCooldownRemaining: TimeInterval = 0

    init(world: SKNode, actionRunner: SKNode, physics: PhysicsMasks) {
        self.world = world
        self.actionRunner = actionRunner
        self.physics = physics
    }

    func spawnBoss(sceneSize: CGSize, playerPosition: CGPoint) {
        let node = BossNode(radius: 34, maxHP: 520, moveSpeed: 70, contactDamage: 16)
        node.position = bossSpawnPoint(sceneSize: sceneSize, playerPosition: playerPosition)
        world.addChild(node)
        boss = node
        phase2 = false
        stompCooldownRemaining = 2.2
    }

    func clearBoss() {
        boss?.removeFromParent()
        boss = nil
        phase2 = false
        stompCooldownRemaining = 0
    }

    func step(dt: TimeInterval, sceneSize: CGSize, playerPosition: CGPoint) {
        guard dt > 0, let boss, boss.hp > 0 else { return }

        if !phase2, boss.hp <= boss.maxHP * 0.5 {
            phase2 = true
            stompCooldownRemaining = 1.0

            let flash = SKSpriteNode(color: SKColor(white: 1, alpha: 0.22), size: sceneSize)
            flash.zPosition = 9999
            world.addChild(flash)
            flash.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
            boss.setScale(1.08)
        }

        if phase2 {
            stompCooldownRemaining -= dt
            if stompCooldownRemaining <= 0 {
                stompCooldownRemaining = 4.0
                performVoidStomp(from: boss, sceneSize: sceneSize)
            }
        }

        let toPlayer = CGVector(dx: playerPosition.x - boss.position.x, dy: playerPosition.y - boss.position.y)
        let dir = normalize(toPlayer)
        boss.position.x += dir.dx * boss.moveSpeed * CGFloat(dt)
        boss.position.y += dir.dy * boss.moveSpeed * CGFloat(dt)
    }

    private func bossSpawnPoint(sceneSize: CGSize, playerPosition: CGPoint) -> CGPoint {
        let halfW = sceneSize.width * 0.5
        let halfH = sceneSize.height * 0.5
        let margin: CGFloat = 30
        let side = Int.random(in: 0..<4)
        switch side {
        case 0: return CGPoint(x: playerPosition.x - halfW - margin, y: playerPosition.y)
        case 1: return CGPoint(x: playerPosition.x + halfW + margin, y: playerPosition.y)
        case 2: return CGPoint(x: playerPosition.x, y: playerPosition.y - halfH - margin)
        default: return CGPoint(x: playerPosition.x, y: playerPosition.y + halfH + margin)
        }
    }

    private func performVoidStomp(from boss: BossNode, sceneSize: CGSize) {
        let tell = SKShapeNode(circleOfRadius: 46)
        tell.position = boss.position
        tell.fillColor = SKColor(white: 1, alpha: 0.08)
        tell.strokeColor = SKColor(white: 1, alpha: 0.22)
        tell.lineWidth = 2
        tell.zPosition = 80
        world.addChild(tell)
        tell.run(.sequence([.scale(to: 1.25, duration: 0.25), .fadeOut(withDuration: 0.2), .removeFromParent()]))

        actionRunner?.run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in
            self?.spawnStompShockwaves(at: boss.position, sceneSize: sceneSize)
        }]))
    }

    private func spawnStompShockwaves(at origin: CGPoint, sceneSize: CGSize) {
        let duration: TimeInterval = 0.6
        let thickness: CGFloat = 26
        let maxLen = max(sceneSize.width, sceneSize.height) * 1.2
        let startLen: CGFloat = 40

        func makeWave(rotation: CGFloat) -> SKShapeNode {
            let node = SKShapeNode(rectOf: CGSize(width: startLen, height: thickness), cornerRadius: 6)
            node.fillColor = SKColor(white: 1, alpha: 0.14)
            node.strokeColor = SKColor(white: 1, alpha: 0.22)
            node.lineWidth = 2
            node.zRotation = rotation
            node.position = origin
            node.zPosition = 90
            let body = SKPhysicsBody(rectangleOf: CGSize(width: startLen, height: thickness))
            body.affectedByGravity = false
            body.allowsRotation = false
            body.isDynamic = false
            body.categoryBitMask = physics.bossAttack
            body.collisionBitMask = physics.none
            body.contactTestBitMask = physics.player
            node.physicsBody = body
            return node
        }

        let h = makeWave(rotation: 0)
        let v = makeWave(rotation: .pi / 2)
        world.addChild(h)
        world.addChild(v)

        let expand = SKAction.customAction(withDuration: duration) { [physics] node, t in
            let p = t / CGFloat(duration)
            let w = startLen + (maxLen - startLen) * p
            let rect = CGRect(x: -w / 2, y: -thickness / 2, width: w, height: thickness)
            (node as? SKShapeNode)?.path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)

            let body = SKPhysicsBody(rectangleOf: CGSize(width: w, height: thickness))
            body.affectedByGravity = false
            body.allowsRotation = false
            body.isDynamic = false
            body.categoryBitMask = physics.bossAttack
            body.collisionBitMask = physics.none
            body.contactTestBitMask = physics.player
            node.physicsBody = body
        }

        h.run(.sequence([expand, .removeFromParent()]))
        v.run(.sequence([expand, .removeFromParent()]))
    }

    private func normalize(_ v: CGVector) -> CGVector {
        let len = sqrt(v.dx * v.dx + v.dy * v.dy)
        guard len > 0.0001 else { return .zero }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }
}

