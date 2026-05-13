import SpriteKit

final class BossSystem {
    struct PhysicsMasks {
        let bossAttack: UInt32
        let player: UInt32
        let none: UInt32
    }

    private let world: SKNode
    private let physics: PhysicsMasks

    private(set) var boss: BossNode?

    /// Circle AOE around the boss (world units).
    private let aoeRadius: CGFloat = 152
    private let aoeWindup: TimeInterval = 1.35
    private let aoeStrikeDuration: TimeInterval = 0.16
    private let aoeCooldown: TimeInterval = 2.75
    private let aoeDamage: CGFloat = 38
    /// Chasing speed multiplier while the telegraph is winding up (readable tell).
    private let telegraphMoveFactor: CGFloat = 0.28

    private enum Phase {
        case idle(remaining: TimeInterval)
        case telegraph(elapsed: TimeInterval)
        case striking(remaining: TimeInterval)
    }

    private var phase: Phase = .idle(remaining: 2.35)
    private var telegraphShape: SKShapeNode?
    private var strikeShape: SKShapeNode?

    init(world: SKNode, physics: PhysicsMasks) {
        self.world = world
        self.physics = physics
    }

    func spawnBoss(sceneSize: CGSize, playerPosition: CGPoint) {
        cleanupAttackVisuals()
        let node = BossNode(radius: 34, maxHP: 520, moveSpeed: 70, contactDamage: 62)
        node.position = bossSpawnPoint(sceneSize: sceneSize, playerPosition: playerPosition)
        world.addChild(node)
        boss = node
        phase = .idle(remaining: 2.2)
    }

    func clearBoss() {
        cleanupAttackVisuals()
        boss?.removeFromParent()
        boss = nil
        phase = .idle(remaining: 2.35)
    }

    func step(dt: TimeInterval, sceneSize: CGSize, playerPosition: CGPoint) {
        guard dt > 0, let boss, boss.hp > 0 else {
            cleanupAttackVisuals()
            return
        }

        let toPlayer = CGVector(dx: playerPosition.x - boss.position.x, dy: playerPosition.y - boss.position.y)
        let dir = normalize(toPlayer)

        var moveFactor: CGFloat = 1.0
        switch phase {
        case .idle(let remaining):
            let next = remaining - dt
            if next <= 0 {
                beginTelegraph(on: boss)
                phase = .telegraph(elapsed: 0)
            } else {
                phase = .idle(remaining: next)
            }

        case .telegraph(let elapsed):
            moveFactor = telegraphMoveFactor
            let nextElapsed = elapsed + dt
            updateTelegraph(radiusFraction: CGFloat(min(1, nextElapsed / aoeWindup)))
            if nextElapsed >= aoeWindup {
                endTelegraph()
                beginStrike(on: boss)
                phase = .striking(remaining: aoeStrikeDuration)
            } else {
                phase = .telegraph(elapsed: nextElapsed)
            }

        case .striking(let remaining):
            let next = remaining - dt
            if next <= 0 {
                endStrike()
                phase = .idle(remaining: aoeCooldown)
            } else {
                phase = .striking(remaining: next)
            }
        }

        let speed = boss.moveSpeed * moveFactor
        boss.position.x += dir.dx * speed * CGFloat(dt)
        boss.position.y += dir.dy * speed * CGFloat(dt)
    }

    private func beginTelegraph(on boss: BossNode) {
        endTelegraph()
        let r: CGFloat = 10
        let shape = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil))
        shape.fillColor = SKColor(red: 1, green: 0.22, blue: 0.06, alpha: 0.14)
        shape.strokeColor = SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 0.5)
        shape.lineWidth = 2.5
        shape.zPosition = -3
        shape.name = "boss_aoe_telegraph"
        boss.addChild(shape)
        telegraphShape = shape
    }

    private func updateTelegraph(radiusFraction: CGFloat) {
        guard let shape = telegraphShape else { return }
        let rMin: CGFloat = 10
        let r = rMin + (aoeRadius - rMin) * radiusFraction
        shape.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        let fillA = 0.12 + 0.28 * radiusFraction
        shape.fillColor = SKColor(red: 1, green: 0.12 + 0.2 * radiusFraction, blue: 0.04, alpha: fillA)
        shape.strokeColor = SKColor(red: 1, green: 0.45 + 0.35 * radiusFraction, blue: 0.12, alpha: 0.48 + 0.42 * radiusFraction)
        shape.lineWidth = 2.5 + 3.5 * radiusFraction
    }

    private func endTelegraph() {
        telegraphShape?.removeFromParent()
        telegraphShape = nil
    }

    private func beginStrike(on boss: BossNode) {
        endStrike()
        let shape = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -aoeRadius, y: -aoeRadius, width: 2 * aoeRadius, height: 2 * aoeRadius), transform: nil))
        shape.fillColor = SKColor(red: 1, green: 0.35, blue: 0.08, alpha: 0.22)
        shape.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 0.95)
        shape.lineWidth = 5
        shape.zPosition = 4
        shape.name = "boss_aoe_strike"

        let body = SKPhysicsBody(circleOfRadius: aoeRadius)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.isDynamic = false
        body.categoryBitMask = physics.bossAttack
        body.collisionBitMask = physics.none
        body.contactTestBitMask = physics.player
        shape.physicsBody = body

        let ud = NSMutableDictionary()
        ud["bossAoeDmg"] = NSNumber(value: Double(aoeDamage))
        shape.userData = ud

        boss.addChild(shape)
        strikeShape = shape

        shape.run(
            .sequence([
                .wait(forDuration: aoeStrikeDuration * 0.45),
                .fadeAlpha(to: 0.08, duration: aoeStrikeDuration * 0.55)
            ])
        )
    }

    private func endStrike() {
        strikeShape?.removeAllActions()
        strikeShape?.removeFromParent()
        strikeShape = nil
    }

    private func cleanupAttackVisuals() {
        endTelegraph()
        endStrike()
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

    private func normalize(_ v: CGVector) -> CGVector {
        let len = sqrt(v.dx * v.dx + v.dy * v.dy)
        guard len > 0.0001 else { return .zero }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }
}
