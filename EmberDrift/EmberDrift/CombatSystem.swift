import SpriteKit

final class CombatSystem {
    struct Tuning {
        let baseAttackDamage: CGFloat
        let burnDuration: TimeInterval
    }

    // Core tuning/state
    var attackInterval: TimeInterval = 1.2
    var attackRadius: CGFloat = 120
    var damageMultiplier: CGFloat = 1.0

    var burnDps: CGFloat = 0.0
    var eruptionChance: Double = 0.0

    private let tuning: Tuning
    private var attackCooldownRemaining: TimeInterval = 0

    init(tuning: Tuning) {
        self.tuning = tuning
    }

    struct RingResult {
        let killedEnemies: [EnemyNode]
        let bossKilled: Bool
    }

    struct DotResult {
        let killedEnemies: [EnemyNode]
    }

    func stepRing(
        dt: TimeInterval,
        world: SKNode,
        playerPosition: CGPoint,
        enemies: inout [EnemyNode],
        boss: BossNode?
    ) -> RingResult? {
        guard dt > 0 else { return nil }
        attackCooldownRemaining -= dt
        guard attackCooldownRemaining <= 0 else { return nil }
        attackCooldownRemaining = attackInterval

        // Visual ring
        let ring = SKShapeNode(circleOfRadius: attackRadius)
        ring.position = playerPosition
        ring.strokeColor = SKColor(white: 1, alpha: 0.65)
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.zPosition = 100
        world.addChild(ring)
        ring.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))

        // Damage all enemies in radius
        let radiusSq = attackRadius * attackRadius
        var killed: [EnemyNode] = []
        for enemy in enemies where !enemy.isHidden {
            let dx = enemy.position.x - playerPosition.x
            let dy = enemy.position.y - playerPosition.y
            if (dx * dx + dy * dy) <= radiusSq {
                let dmg = tuning.baseAttackDamage * damageMultiplier
                enemy.hp = max(0, enemy.hp - dmg)

                // Afterburn: apply burn DoT
                if burnDps > 0 {
                    if enemy.userData == nil { enemy.userData = NSMutableDictionary() }
                    enemy.userData?["burnRemaining"] = tuning.burnDuration
                }
                if enemy.hp <= 0 {
                    killed.append(enemy)
                }
            }
        }

        // Boss takes damage from Ember Ring too.
        var bossKilled = false
        if let boss, boss.hp > 0 {
            let dx = boss.position.x - playerPosition.x
            let dy = boss.position.y - playerPosition.y
            if (dx * dx + dy * dy) <= radiusSq {
                let dmg = tuning.baseAttackDamage * damageMultiplier
                boss.hp = max(0, boss.hp - dmg)
                if boss.hp <= 0 {
                    bossKilled = true
                }
            }
        }

        return RingResult(killedEnemies: killed, bossKilled: bossKilled)
    }

    func stepDots(dt: TimeInterval, enemies: [EnemyNode]) -> DotResult? {
        guard dt > 0, burnDps > 0 else { return nil }
        var killed: [EnemyNode] = []
        for enemy in enemies where !enemy.isHidden {
            guard let ud = enemy.userData else { continue }
            let remaining = (ud["burnRemaining"] as? Double) ?? 0
            if remaining <= 0 { continue }
            let newRemaining = max(0, remaining - dt)
            ud["burnRemaining"] = newRemaining
            enemy.hp = max(0, enemy.hp - burnDps * CGFloat(dt))
            if enemy.hp <= 0 {
                killed.append(enemy)
            }
        }
        return DotResult(killedEnemies: killed)
    }

    func tryEruptionFromKill(
        origin: CGPoint,
        enemies: inout [EnemyNode],
        spawnXPOrb: (CGPoint, Int) -> Void,
        onKillCounted: (EnemyNode) -> Void
    ) {
        guard eruptionChance > 0, Double.random(in: 0...1) < eruptionChance else { return }
        let radius: CGFloat = 95
        let dmg = tuning.baseAttackDamage * damageMultiplier * 1.2
        let r2 = radius * radius
        for other in enemies where !other.isHidden {
            let dx = other.position.x - origin.x
            let dy = other.position.y - origin.y
            if (dx * dx + dy * dy) <= r2 {
                other.hp = max(0, other.hp - dmg)
                if other.hp <= 0 {
                    // avoid recursion explosion; mark and clean later
                    other.isHidden = true
                    other.removeFromParent()
                    onKillCounted(other)
                    let xp2 = (other.kind == .scuttler) ? 4 : 10
                    spawnXPOrb(other.position, xp2)
                }
            }
        }
        enemies.removeAll(where: { $0.parent == nil || $0.isHidden })
    }
}

