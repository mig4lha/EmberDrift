import SpriteKit

final class CombatSystem {
    private var attackCooldown: TimeInterval = 0

    func update(
        dt: TimeInterval,
        player: PlayerNode,
        modifiers: InRunModifiers,
        enemies: [EnemyNode],
        boss: BossNode?,
        onEnemyHit: (EnemyNode, CGFloat) -> Void,
        onBossHit: (BossNode, CGFloat) -> Void
    ) {
        attackCooldown -= dt
        if attackCooldown <= 0 {
            attackCooldown = max(0.15, modifiers.attackInterval)
            performEmberRing(player: player, modifiers: modifiers, enemies: enemies, boss: boss, onEnemyHit: onEnemyHit, onBossHit: onBossHit)
        }
    }

    private func performEmberRing(
        player: PlayerNode,
        modifiers: InRunModifiers,
        enemies: [EnemyNode],
        boss: BossNode?,
        onEnemyHit: (EnemyNode, CGFloat) -> Void,
        onBossHit: (BossNode, CGFloat) -> Void
    ) {
        let radius = modifiers.attackRadius
        let radiusSq = radius * radius
        let baseDamage: CGFloat = 10
        let dmg = baseDamage * modifiers.damageMultiplier

        for enemy in enemies where !enemy.isHidden {
            let dx = enemy.position.x - player.position.x
            let dy = enemy.position.y - player.position.y
            if (dx * dx + dy * dy) <= radiusSq {
                onEnemyHit(enemy, dmg)
            }
        }

        if let boss {
            let dx = boss.position.x - player.position.x
            let dy = boss.position.y - player.position.y
            if (dx * dx + dy * dy) <= radiusSq {
                onBossHit(boss, dmg)
            }
        }

        // Visual ring
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = player.position
        ring.strokeColor = .systemOrange
        ring.lineWidth = 2
        ring.fillColor = .clear
        ring.alpha = 0.5
        ring.zPosition = 10
        player.parent?.addChild(ring)
        ring.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
    }
}

