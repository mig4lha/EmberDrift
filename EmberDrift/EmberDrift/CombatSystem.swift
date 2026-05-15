import SpriteKit

final class CombatSystem {
    struct Tuning {
        let baseAttackDamage: CGFloat
        let burnDuration: TimeInterval
    }

    // Core tuning/state
    var attackInterval: TimeInterval = 0.92
    var attackRadius: CGFloat = 159
    var damageMultiplier: CGFloat = 1.0

    var burnDps: CGFloat = 0.0
    var eruptionChance: Double = 0.0
    var eruptionRadius: CGFloat = 72
    var eruptionDamageMultiplier: CGFloat = 0.85

    /// Stacks from Ember Bolt power-up (0 = disabled).
    private(set) var boltStacks: Int = 0

    private let tuning: Tuning
    private var attackCooldownRemaining: TimeInterval = 0
    private var boltCooldownRemaining: TimeInterval = 0
    private var boltVolleyShotsRemaining: Int = 0
    private var boltBetweenShotCooldown: TimeInterval = 0
    private var boltVolleyTargetedIDs: Set<ObjectIdentifier> = []

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

    struct BoltResult {
        let killedEnemies: [EnemyNode]
        let bossKilled: Bool
    }

    func setBoltStacks(_ stacks: Int) {
        boltStacks = max(0, stacks)
        boltVolleyShotsRemaining = 0
        boltBetweenShotCooldown = 0
        boltVolleyTargetedIDs.removeAll()
        if boltStacks > 0, boltCooldownRemaining <= 0, boltVolleyShotsRemaining == 0 {
            boltCooldownRemaining = boltInterval * 0.35
        }
    }

    /// 2 / 4 / 8 projectiles at stacks 1 / 2 / 3.
    private var boltProjectileCount: Int {
        guard boltStacks > 0 else { return 0 }
        return 1 << boltStacks
    }

    private var boltInterval: TimeInterval {
        guard boltStacks > 0 else { return .infinity }
        // Stack 1: ~1.15s, stack 2: ~0.72s, stack 3: ~0.45s between volleys
        return max(0.42, 1.15 * pow(0.63, Double(boltStacks - 1)))
    }

    private var boltDamage: CGFloat {
        guard boltStacks > 0 else { return 0 }
        let base: CGFloat = 8 + CGFloat(boltStacks - 1) * 2
        return base * damageMultiplier
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

                // Afterburn: apply burn DoT
                if burnDps > 0 {
                    if enemy.userData == nil { enemy.userData = NSMutableDictionary() }
                    enemy.userData?["burnRemaining"] = tuning.burnDuration
                }
                if enemy.applyDamage(dmg) {
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
                if boss.applyDamage(dmg) {
                    bossKilled = true
                }
            }
        }

        return RingResult(killedEnemies: killed, bossKilled: bossKilled)
    }

    func stepBolt(
        dt: TimeInterval,
        world: SKNode,
        playerPosition: CGPoint,
        enemies: inout [EnemyNode],
        boss: BossNode?
    ) -> BoltResult? {
        guard dt > 0, boltStacks > 0 else { return nil }

        var killed: [EnemyNode] = []
        var bossKilled = false
        var didFire = false

        func merge(_ shot: (killed: [EnemyNode], bossKilled: Bool)?) {
            guard let shot else { return }
            didFire = true
            for enemy in shot.killed where !killed.contains(where: { $0 === enemy }) {
                killed.append(enemy)
            }
            if shot.bossKilled { bossKilled = true }
        }

        if boltVolleyShotsRemaining > 0 {
            boltBetweenShotCooldown -= dt
            guard boltBetweenShotCooldown <= 0 else { return nil }

            let liveCount = liveBoltTargetCount(enemies: enemies, boss: boss)
            merge(fireOneBolt(
                world: world,
                from: playerPosition,
                enemies: enemies,
                boss: boss,
                allowRepeatTarget: liveCount <= 1
            ))

            boltVolleyShotsRemaining -= 1
            if boltVolleyShotsRemaining > 0 {
                boltBetweenShotCooldown = boltShotSpacing(singleTarget: liveCount <= 1)
            } else {
                boltVolleyTargetedIDs.removeAll()
                boltCooldownRemaining = boltInterval
            }
        } else {
            boltCooldownRemaining -= dt
            guard boltCooldownRemaining <= 0 else { return nil }

            let liveCount = liveBoltTargetCount(enemies: enemies, boss: boss)
            guard liveCount > 0 else {
                boltCooldownRemaining = 0.25
                return nil
            }

            boltVolleyShotsRemaining = boltProjectileCount
            boltVolleyTargetedIDs.removeAll()

            merge(fireOneBolt(
                world: world,
                from: playerPosition,
                enemies: enemies,
                boss: boss,
                allowRepeatTarget: liveCount <= 1
            ))

            boltVolleyShotsRemaining -= 1
            if boltVolleyShotsRemaining > 0 {
                boltBetweenShotCooldown = boltShotSpacing(singleTarget: liveCount <= 1)
            } else {
                boltCooldownRemaining = boltInterval
            }
        }

        return didFire ? BoltResult(killedEnemies: killed, bossKilled: bossKilled) : nil
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
        let radius = eruptionRadius
        let dmg = tuning.baseAttackDamage * damageMultiplier * eruptionDamageMultiplier
        let r2 = radius * radius
        for other in enemies where !other.isHidden {
            let dx = other.position.x - origin.x
            let dy = other.position.y - origin.y
            if (dx * dx + dy * dy) <= r2 {
                if other.applyDamage(dmg) {
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

    // MARK: - Bolt helpers

    private enum BoltTargetKind {
        case enemy(EnemyNode)
        case boss(BossNode)
    }

    private struct BoltTarget {
        let kind: BoltTargetKind
        let position: CGPoint
        let distanceSq: CGFloat
    }

    private func boltShotSpacing(singleTarget: Bool) -> TimeInterval {
        singleTarget ? 0.08 : 0.055
    }

    private func liveBoltTargetCount(enemies: [EnemyNode], boss: BossNode?) -> Int {
        var count = enemies.filter { !$0.isHidden && $0.hp > 0 }.count
        if let boss, boss.hp > 0 { count += 1 }
        return count
    }

    private func boltTargetID(_ target: BoltTarget) -> ObjectIdentifier {
        switch target.kind {
        case .enemy(let enemy): return ObjectIdentifier(enemy)
        case .boss(let boss): return ObjectIdentifier(boss)
        }
    }

    private func sortedBoltCandidates(
        from origin: CGPoint,
        enemies: [EnemyNode],
        boss: BossNode?
    ) -> [BoltTarget] {
        var candidates: [BoltTarget] = []
        for enemy in enemies where !enemy.isHidden && enemy.hp > 0 {
            let dx = enemy.position.x - origin.x
            let dy = enemy.position.y - origin.y
            candidates.append(BoltTarget(kind: .enemy(enemy), position: enemy.position, distanceSq: dx * dx + dy * dy))
        }
        if let boss, boss.hp > 0 {
            let dx = boss.position.x - origin.x
            let dy = boss.position.y - origin.y
            candidates.append(BoltTarget(kind: .boss(boss), position: boss.position, distanceSq: dx * dx + dy * dy))
        }
        candidates.sort { $0.distanceSq < $1.distanceSq }
        return candidates
    }

    private func pickNextBoltTarget(
        from origin: CGPoint,
        enemies: [EnemyNode],
        boss: BossNode?,
        allowRepeatTarget: Bool
    ) -> BoltTarget? {
        let candidates = sortedBoltCandidates(from: origin, enemies: enemies, boss: boss)
        guard !candidates.isEmpty else { return nil }

        if !allowRepeatTarget {
            if let untargeted = candidates.first(where: { !boltVolleyTargetedIDs.contains(boltTargetID($0)) }) {
                return untargeted
            }
            // More bolts than foes: spread to next-nearest already-hit targets.
            let overflowIndex = boltVolleyTargetedIDs.count % candidates.count
            return candidates[overflowIndex]
        }
        return candidates.first
    }

    private func fireOneBolt(
        world: SKNode,
        from origin: CGPoint,
        enemies: [EnemyNode],
        boss: BossNode?,
        allowRepeatTarget: Bool
    ) -> (killed: [EnemyNode], bossKilled: Bool)? {
        guard let target = pickNextBoltTarget(
            from: origin,
            enemies: enemies,
            boss: boss,
            allowRepeatTarget: allowRepeatTarget
        ) else { return nil }

        if !allowRepeatTarget {
            boltVolleyTargetedIDs.insert(boltTargetID(target))
        }

        spawnBoltVisual(in: world, from: origin, to: target.position)

        var killed: [EnemyNode] = []
        var bossKilled = false
        let dmg = boltDamage

        switch target.kind {
        case .enemy(let enemy):
            if burnDps > 0 {
                if enemy.userData == nil { enemy.userData = NSMutableDictionary() }
                enemy.userData?["burnRemaining"] = tuning.burnDuration
            }
            if enemy.applyDamage(dmg) {
                killed.append(enemy)
            }
        case .boss(let bossNode):
            if bossNode.applyDamage(dmg) {
                bossKilled = true
            }
        }

        return (killed, bossKilled)
    }

    private func spawnBoltVisual(in world: SKNode, from start: CGPoint, to end: CGPoint) {
        let bolt = SKShapeNode(circleOfRadius: 5)
        bolt.fillColor = SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 0.95)
        bolt.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.9)
        bolt.lineWidth = 1.5
        bolt.position = start
        bolt.zPosition = 110
        world.addChild(bolt)

        let travel = hypot(end.x - start.x, end.y - start.y)
        let duration = min(0.22, max(0.08, TimeInterval(travel / 900)))
        bolt.run(.sequence([
            .move(to: end, duration: duration),
            .fadeOut(withDuration: 0.06),
            .removeFromParent(),
        ]))
    }
}
