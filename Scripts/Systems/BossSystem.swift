import SpriteKit

final class BossSystem {
    enum State {
        case inactive
        case phase1
        case phase2
        case dead
    }

    private weak var parent: SKNode?
    private weak var cameraNode: SKCameraNode?

    private(set) var boss: BossNode?
    private(set) var state: State = .inactive

    private var stompCooldown: TimeInterval = 0

    init(parent: SKNode, cameraNode: SKCameraNode) {
        self.parent = parent
        self.cameraNode = cameraNode
    }

    func spawnBoss(near playerPos: CGPoint) {
        guard boss == nil, let parent else { return }
        let boss = BossNode(maxHP: 650, moveSpeed: 55, contactDamage: 26)
        boss.position = spawnPositionAtCameraEdge(playerPos: playerPos)
        parent.addChild(boss)
        self.boss = boss
        self.state = .phase1
        self.stompCooldown = 2.0
    }

    func update(dt: TimeInterval, player: PlayerNode) {
        guard let boss, state != .inactive, state != .dead else { return }

        if boss.hp <= 0 {
            state = .dead
            boss.removeFromParent()
            self.boss = nil
            return
        }

        if state == .phase1, boss.hp <= boss.maxHP * 0.5 {
            state = .phase2
            // Small phase flash
            let flash = SKSpriteNode(color: SKColor(white: 1, alpha: 0.25), size: cameraNode?.scene?.size ?? .zero)
            flash.zPosition = 2000
            cameraNode?.addChild(flash)
            flash.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        }

        // Move toward player unless stomping.
        stompCooldown -= dt
        let isStompingNow = (state == .phase2 && stompCooldown <= 0.5)
        if !isStompingNow {
            let dir = (player.position - boss.position).normalized()
            boss.position = boss.position + (dir * boss.moveSpeed * dt)
        }

        if state == .phase2, stompCooldown <= 0 {
            stompCooldown = 4.0
            performStomp(from: boss.position)
        }
    }

    private func performStomp(from origin: CGPoint) {
        guard let parent else { return }

        for axis in 0..<4 {
            let horizontal = axis < 2
            let sign: CGFloat = (axis % 2 == 0) ? 1 : -1

            let size = horizontal ? CGSize(width: 14, height: 60) : CGSize(width: 60, height: 14)
            let wave = SKShapeNode(rectOf: size, cornerRadius: 6)
            wave.fillColor = .systemIndigo
            wave.strokeColor = .clear
            wave.alpha = 0.75
            wave.zPosition = 15
            wave.position = origin
            parent.addChild(wave)

            let body = SKPhysicsBody(rectangleOf: size)
            body.affectedByGravity = false
            body.allowsRotation = false
            body.categoryBitMask = PhysicsCategory.bossAttack
            body.collisionBitMask = PhysicsCategory.none
            body.contactTestBitMask = PhysicsCategory.player
            wave.physicsBody = body

            let distance: CGFloat = 760
            let dx = horizontal ? distance * sign : 0
            let dy = horizontal ? 0 : distance * sign
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.6)
            move.timingMode = .easeOut
            wave.run(.sequence([move, .removeFromParent()]))
        }
    }

    private func spawnPositionAtCameraEdge(playerPos: CGPoint) -> CGPoint {
        guard let cam = cameraNode else { return playerPos }
        let w = cam.scene?.size.width ?? 0
        let h = cam.scene?.size.height ?? 0
        let halfW = w * 0.5
        let halfH = h * 0.5
        let margin: CGFloat = 50

        let side = Int.random(in: 0..<4)
        switch side {
        case 0:
            return CGPoint(x: playerPos.x - halfW - margin, y: playerPos.y)
        case 1:
            return CGPoint(x: playerPos.x + halfW + margin, y: playerPos.y)
        case 2:
            return CGPoint(x: playerPos.x, y: playerPos.y - halfH - margin)
        default:
            return CGPoint(x: playerPos.x, y: playerPos.y + halfH + margin)
        }
    }
}

