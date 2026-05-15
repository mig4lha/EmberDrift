import SpriteKit

final class GameScene: SKScene {
    private let input = InputController()

    private let world = SKNode()
    private let cameraNode = SKCameraNode()

    private var player: PlayerNode!
    private var mapTiling: MapTilingSystem!
    private var enemyPool: EnemyPool!
    private var spawnSystem: SpawnSystem!
    private var activeEnemies: [EnemyNode] = []

    private let hud = HUDNode()
    private let levelUpOverlay = LevelUpOverlay()

    private let xpSystem: XPSystem
    private let powerUps = PowerUpSystem()
    private var modifiers = InRunModifiers()
    private let combat = CombatSystem()
    private var bossSystem: BossSystem!

    private var pendingLevelUps: Int = 0
    private var isLevelUpPresented: Bool = false
    private var nextLevelCardCountOverride: Int?
    private var runStats = RunStats(timeSurvivedSeconds: 0, enemiesKilledByType: [:], finalLevel: 1, powerUpsTaken: [], ashEarned: 0)
    private var didVoidSurge: Bool = false
    private var pruneTimer: TimeInterval = 0

    private var elapsed: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?
    private var isRunning: Bool = true

    override init(size: CGSize) {
        self.xpSystem = XPSystem(parent: world)
        super.init(size: size)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        addChild(world)

        camera = cameraNode
        addChild(cameraNode)

        player = PlayerNode(maxHP: GameConstants.basePlayerMaxHP)
        player.position = .zero
        world.addChild(player)

        applyMetaProgression()

        mapTiling = MapTilingSystem(parent: world, tileSize: 512)

        enemyPool = EnemyPool(parent: world, capacity: 60)
        spawnSystem = SpawnSystem(pool: enemyPool, cameraNode: cameraNode)
        bossSystem = BossSystem(parent: world, cameraNode: cameraNode)

        cameraNode.addChild(hud)
        hud.layout(for: size)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        hud.layout(for: size)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard isRunning else { return }

        let dt: TimeInterval
        if let last = lastUpdateTime {
            dt = min(1.0 / 30.0, currentTime - last)
        } else {
            dt = 1.0 / 60.0
        }
        lastUpdateTime = currentTime

        elapsed += dt
        if player.hp <= 0 {
            endRun()
            return
        }

        // Void surge at 5:00 — clear enemies, no XP, spawn boss.
        if !didVoidSurge, elapsed >= GameConstants.runLengthSeconds {
            didVoidSurge = true
            performVoidSurge()
            bossSystem.spawnBoss(near: player.position)
        }

        if !isLevelUpPresented {
            // Move player (world space)
            let move = input.moveVector
            let speed = GameConstants.baseMoveSpeed * modifiers.moveSpeedMultiplier
            player.position = player.position + (move * speed * dt)
            player.tick(dt: dt)

            // Camera follows player
            cameraNode.position = player.position

            // Map tiles
            mapTiling.update(around: player.position)

            // Spawn (stop spawns at 4:45)
            let isSpawningEnabled = elapsed < 285 && !didVoidSurge
            let spawned = spawnSystem.update(elapsed: elapsed, dt: dt, playerPos: player.position, isSpawningEnabled: isSpawningEnabled)
            if !spawned.isEmpty { activeEnemies.append(contentsOf: spawned) }

            // Enemy chase
            for enemy in activeEnemies where !enemy.isHidden {
                let dir = (player.position - enemy.position).normalized()
                enemy.position = enemy.position + (dir * enemy.moveSpeed * dt)
            }

            // Combat
            combat.update(dt: dt, player: player, modifiers: modifiers, enemies: activeEnemies, boss: bossSystem.boss) { [weak self] enemy, damage in
                guard let self else { return }
                enemy.applyDamage(damage)
                if enemy.hp <= 0 {
                    self.onEnemyKilled(enemy)
                }
            } onBossHit: { [weak self] boss, damage in
                guard let self else { return }
                boss.applyDamage(damage)
                self.shakeCamera(intensity: 6)
            }

            // Orb attraction
            xpSystem.updateOrbsTowardPlayer(playerPos: player.position, dt: dt, pullRange: modifiers.magneticPullRange)

            bossSystem.update(dt: dt, player: player)
            if didVoidSurge, bossSystem.state == .dead {
                endRun()
                return
            }

            pruneTimer += dt
            if pruneTimer >= 2.5 {
                pruneTimer = 0
                activeEnemies.removeAll(where: { $0.isHidden })
            }
        } else {
            // Keep HUD timer ticking while paused on level-up
            cameraNode.position = player.position
        }

        if pendingLevelUps > 0, !isLevelUpPresented {
            presentLevelUp()
        }

        hud.update(
            hp: player.hp,
            maxHP: player.maxHP,
            xp: xpSystem.currentXP,
            xpNeeded: xpSystem.xpRequiredForNextLevel(),
            level: xpSystem.level,
            elapsedSeconds: Int(min(elapsed, GameConstants.runLengthSeconds)),
            bossHP: bossSystem.boss?.hp,
            bossMaxHP: bossSystem.boss?.maxHP
        )
    }

    private func endRun() {
        isRunning = false
        runStats.timeSurvivedSeconds = Int(elapsed)
        runStats.finalLevel = xpSystem.level

        let bossKilled = didVoidSurge && bossSystem.state == .dead
        runStats.ashEarned = computeAshEarned(timeSurvived: runStats.timeSurvivedSeconds, bossKilled: bossKilled)

        let stats = RunStats(
            timeSurvivedSeconds: runStats.timeSurvivedSeconds,
            enemiesKilledByType: runStats.enemiesKilledByType,
            finalLevel: runStats.finalLevel,
            powerUpsTaken: runStats.powerUpsTaken,
            ashEarned: runStats.ashEarned
        )
        let scene = RunSummaryScene(size: size, stats: stats)
        scene.scaleMode = .resizeFill
        view?.presentScene(scene, transition: .fade(withDuration: 0.25))
    }

    private func applyMetaProgression() {
        let save = SaveStore.shared.load()

        // Configure power-up pool based on Ember Tree unlocks.
        var allowed = Set(PowerUpKind.allCases)
        if !save.emberTree.secondWind {
            allowed.remove(.rekindle)
        }
        powerUps.configureAllowedKinds(allowed)

        // Stat upgrades
        player.maxHP += CGFloat(save.emberTree.temperedBody) * 10
        player.healToFull()

        modifiers.damageMultiplier *= (1 + CGFloat(save.emberTree.hotterCore) * 0.08)
        modifiers.moveSpeedMultiplier *= (1 + CGFloat(save.emberTree.swiftDrift) * 0.05)
        modifiers.ashMultiplier *= (1 + Double(save.emberTree.emberHoard) * 0.10)

        let atkSpeed = (1 + Double(save.emberTree.stoked) * 0.06)
        modifiers.attackInterval /= atkSpeed

        if save.emberTree.kindlingCache {
            xpSystem.xpMultiplier = 1.1
        }

        if save.emberTree.volatileStart {
            let offensive: [PowerUpKind] = [.scorch, .afterburn, .twinFlame, .eruption, .widerReach, .rapidCycle, .emberBolt]
            if let kind = offensive.randomElement() {
                powerUps.apply(kind, modifiers: &modifiers, player: player)
            }
        }
    }

    private func computeAshEarned(timeSurvived: Int, bossKilled: Bool) -> Int {
        let timeAsh = Int(Double(timeSurvived) / 6.0)
        let bossBonus = bossKilled ? 120 : 0
        let base = timeAsh + bossBonus
        return Int(Double(base) * modifiers.ashMultiplier)
    }

    private func onEnemyKilled(_ enemy: EnemyNode) {
        runStats.enemiesKilledByType[enemy.kind, default: 0] += 1

        let xp = (enemy.kind == .scuttler) ? 4 : 10
        xpSystem.spawnOrb(at: enemy.position, xpValue: xp)
        enemyPool.release(enemy)
    }

    private func performVoidSurge() {
        // Flash
        let flash = SKSpriteNode(color: SKColor(white: 1, alpha: 0.35), size: size)
        flash.zPosition = 3000
        cameraNode.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))

        // Clear all active enemies without dropping XP.
        for enemy in activeEnemies where !enemy.isHidden {
            enemyPool.release(enemy)
        }
        activeEnemies.removeAll(where: { $0.isHidden })
    }

    private func shakeCamera(intensity: CGFloat) {
        cameraNode.removeAction(forKey: "shake")
        let dur = 0.16
        let dx = CGFloat.random(in: -intensity...intensity)
        let dy = CGFloat.random(in: -intensity...intensity)
        let seq = SKAction.sequence([
            .moveBy(x: dx, y: dy, duration: dur * 0.5),
            .moveBy(x: -dx, y: -dy, duration: dur * 0.5),
        ])
        cameraNode.run(seq, withKey: "shake")
    }

    private func presentLevelUp() {
        isLevelUpPresented = true
        Haptics.success()

        // Draw 3 options (or 4 if Overload was taken); if exhausted, apply overflow reward immediately.
        let count = nextLevelCardCountOverride ?? 3
        nextLevelCardCountOverride = nil
        var options = powerUps.drawOptions(count: count)
        if options.isEmpty {
            applyOverflowReward()
            pendingLevelUps = max(0, pendingLevelUps - 1)
            isLevelUpPresented = false
            return
        }

        // Apply Kindling burst rule: only include if other power-ups remain.
        if options.count == 1, options.first == .kindlingBurst {
            applyOverflowReward()
            pendingLevelUps = max(0, pendingLevelUps - 1)
            isLevelUpPresented = false
            return
        }

        let mapped: [LevelUpOverlay.Choice] = options.map { kind in
            LevelUpOverlay.Choice(kind: kind, title: kind.rawValue.uppercased(), subtitle: subtitle(for: kind))
        }

        levelUpOverlay.present(in: cameraNode, sceneSize: size, choices: mapped)
    }

    private func subtitle(for kind: PowerUpKind) -> String {
        switch kind {
        case .scorch: return "+12% damage (stackable)"
        case .afterburn: return "Adds burn damage over time"
        case .twinFlame: return "+28% damage (unique)"
        case .eruption: return "Kills may erupt (stackable)"
        case .widerReach: return "+12% ring radius (stackable)"
        case .rapidCycle: return "Faster attack cycle (stackable)"
        case .emberBolt: return "Bolt volley: 2/4/8 shots (stackable)"
        case .emberShell: return "One-hit shield, regen 15s"
        case .heatSink: return "+30 max HP (stackable)"
        case .rekindle: return "Revive once at 40% HP"
        case .draft: return "+20% move speed (stackable)"
        case .magneticPull: return "Pull XP orbs from farther away"
        case .glowingCoals: return "+8% XP earned (stackable)"
        case .kindlingBurst: return "Immediately gain another level-up"
        case .ashTithe: return "+50% Ash this run"
        case .overload: return "Next level-up shows 4 cards"
        }
    }

    private func applyOverflowReward() {
        player.maxHP += 15
        player.healToFull()
        modifiers.damageMultiplier *= 1.10
    }

    // MARK: touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let camLoc = t.location(in: cameraNode)
        if isLevelUpPresented, let pick = levelUpOverlay.hitTestPick(at: camLoc) {
            handleLevelUpPick(pick)
            return
        }
        input.beginTouch(t, at: t.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        input.moveTouch(t, to: t.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        input.endTouch(t)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        input.endTouch(t)
    }
}

extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask
        let pair = (a, b)

        if pair == (PhysicsCategory.player, PhysicsCategory.enemy) || pair == (PhysicsCategory.enemy, PhysicsCategory.player) {
            let enemyNode = (contact.bodyA.categoryBitMask == PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node) as? EnemyNode
            if let enemyNode {
                let reduced = enemyNode.contactDamage * (1 - modifiers.damageReduction)
                if player.applyDamage(reduced) {
                    shakeCamera(intensity: 8)
                    Haptics.mediumImpact()
                }
            }
        }

        if pair == (PhysicsCategory.player, PhysicsCategory.boss) || pair == (PhysicsCategory.boss, PhysicsCategory.player) {
            // Boss contact damage
            let boss = (contact.bodyA.categoryBitMask == PhysicsCategory.boss ? contact.bodyA.node : contact.bodyB.node) as? BossNode
            if let boss {
                let reduced = boss.contactDamage * (1 - modifiers.damageReduction)
                if player.applyDamage(reduced) {
                    shakeCamera(intensity: 10)
                    Haptics.mediumImpact()
                }
            }
        }

        if pair == (PhysicsCategory.player, PhysicsCategory.bossAttack) || pair == (PhysicsCategory.bossAttack, PhysicsCategory.player) {
            if player.applyDamage(22) {
                shakeCamera(intensity: 10)
                Haptics.mediumImpact()
            }
        }

        if pair == (PhysicsCategory.player, PhysicsCategory.xpOrb) || pair == (PhysicsCategory.xpOrb, PhysicsCategory.player) {
            let orb = (contact.bodyA.categoryBitMask == PhysicsCategory.xpOrb ? contact.bodyA.node : contact.bodyB.node) as? XPOrbNode
            if let orb {
                let leveledUp = xpSystem.collectOrb(orb)
                if leveledUp { pendingLevelUps += 1 }
            }
        }
    }
}

private extension GameScene {
    func handleLevelUpPick(_ kind: PowerUpKind) {
        // Remove overlay
        levelUpOverlay.removeFromParent()
        isLevelUpPresented = false

        if kind == .kindlingBurst {
            pendingLevelUps += 1
        }
        if kind == .overload {
            nextLevelCardCountOverride = 4
        }

        runStats.powerUpsTaken.append(kind)
        powerUps.apply(kind, modifiers: &modifiers, player: player)
        Haptics.lightImpact()
        pendingLevelUps = max(0, pendingLevelUps - 1)
    }
}

