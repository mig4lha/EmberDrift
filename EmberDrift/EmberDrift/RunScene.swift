import SpriteKit

final class RunScene: SKScene, SKPhysicsContactDelegate {
    enum Physics {
        static let none: UInt32 = 0
        static let player: UInt32 = 1 << 0
        static let enemy: UInt32 = 1 << 1
        static let xpOrb: UInt32 = 1 << 2
        static let boss: UInt32 = 1 << 3
        static let bossAttack: UInt32 = 1 << 4
    }

    private let world = SKNode()
    private let cameraNode = SKCameraNode()

    // Map tiling (3x3)
    private let tileSize = CGSize(width: 512, height: 512)
    private var tiles: [SKSpriteNode] = []

    // Player
    private let player = SKSpriteNode(color: .clear, size: CGSize(width: 44, height: 44))
    private let fallbackPlayerShape = SKShapeNode(circleOfRadius: 18)
    private var moveVector = CGVector(dx: 0, dy: 0) // normalized
    private let baseMoveSpeed: CGFloat = 260
    private var moveSpeedMultiplier: CGFloat = 1.0

    // Enemies
    private var enemies: [EnemyNode] = []
    private var scuttlerKills: Int = 0
    private var bruteKills: Int = 0
    private let scuttlerRadius: CGFloat = 16
    private let scuttlerSpeed: CGFloat = 140
    private let scuttlerHP: CGFloat = 16
    private let scuttlerContactDamage: CGFloat = 4

    private let bruteRadius: CGFloat = 22
    private let bruteSpeed: CGFloat = 85
    private let bruteHP: CGFloat = 70
    private let bruteContactDamage: CGFloat = 12
    private lazy var spawner = EnemySpawner(
        world: world,
        tuning: .init(
            scuttlerRadius: scuttlerRadius,
            scuttlerSpeed: scuttlerSpeed,
            scuttlerHP: scuttlerHP,
            scuttlerContactDamage: scuttlerContactDamage,
            bruteRadius: bruteRadius,
            bruteSpeed: bruteSpeed,
            bruteHP: bruteHP,
            bruteContactDamage: bruteContactDamage
        )
    )

    // Run timer
    private var elapsed: TimeInterval = 0
    private let runLengthSeconds: TimeInterval = 300
    private var didVoidSurge: Bool = false

    // Auto-attack (Ember Ring)
    private lazy var combat = CombatSystem(tuning: .init(baseAttackDamage: 8, burnDuration: 3.0))
    private var kills: Int = 0

    // Defensive modifiers
    private var damageReduction: CGFloat = 0.0 // 0...0.30
    private var regenPerSecond: CGFloat = 0.0
    private var maxHP: CGFloat = 100

    // Shield + revive
    private var hasShield: Bool = false
    private var shieldRegenRemaining: TimeInterval = 0
    private var hasRekindle: Bool = false

    // Utility modifiers
    private var ashMultiplier: Double = 1.0
    private var nextLevelCardCountOverride: Int?

    // Afterburn + eruption (stored in `combat`)

    // XP + leveling
    private let xpSystem = XPSystem()
    private var isLevelUpPresented: Bool = false
    private let levelUpOverlay = LevelUpOverlay()

    // Power-ups (GDD)
    private var powerUpStacks: [PowerUpKind: Int] = [:]

    // HUD
    private let hud = HUDOverlay()
    private var hp: CGFloat = 100
    private var lastDamageTime: TimeInterval = -999

    private var lastUpdateTime: TimeInterval?

    // Boss
    private var bossSystem: BossSystem!

    // Run state + debug
    private var isRunning: Bool = true
    private var isInvincible: Bool = false
    private var bossKilled: Bool = false
    private var isPausedByPlayer: Bool = false
    private let pauseOverlay = PauseOverlay()

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        addChild(world)

        camera = cameraNode
        addChild(cameraNode)

        bossSystem = BossSystem(
            world: world,
            actionRunner: self,
            physics: .init(bossAttack: Physics.bossAttack, player: Physics.player, none: Physics.none)
        )

        setupTiles()
        setupPlayer()
        // spawn is continuous now
        hud.attach(to: cameraNode)
        hud.layout(sceneSize: size)
        updateHUD()
    }

    private func setupTiles() {
        tiles.removeAll(keepingCapacity: true)

        for gy in -1...1 {
            for gx in -1...1 {
                let tile: SKSpriteNode
                if let tex = GameAssets.texture(GameAssets.ImageName.tileGround) {
                    tile = SKSpriteNode(texture: tex, size: tileSize)
                } else {
                    tile = SKSpriteNode(
                        color: (gx + gy).isMultiple(of: 2) ? .darkGray : .gray,
                        size: tileSize
                    )
                }
                tile.zPosition = -100
                tile.position = CGPoint(x: CGFloat(gx) * tileSize.width, y: CGFloat(gy) * tileSize.height)
                world.addChild(tile)
                tiles.append(tile)
            }
        }
    }

    private func setupPlayer() {
        if let tex = GameAssets.texture(GameAssets.ImageName.playerCinder) {
            player.texture = tex
            player.size = CGSize(width: 56, height: 56)
        } else {
            fallbackPlayerShape.fillColor = .systemOrange
            fallbackPlayerShape.strokeColor = .clear
            fallbackPlayerShape.zPosition = 1
            player.addChild(fallbackPlayerShape)
        }
        player.position = .zero
        player.zPosition = 10

        let body = SKPhysicsBody(circleOfRadius: 18)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = Physics.player
        body.collisionBitMask = Physics.none
        body.contactTestBitMask = Physics.enemy | Physics.xpOrb | Physics.boss | Physics.bossAttack
        player.physicsBody = body

        world.addChild(player)

        maxHP = 100
        hp = maxHP
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        hud.layout(sceneSize: size)
    }

    // MARK: - Touch movement (Week 1)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let camLoc = touch.location(in: cameraNode)
        let camHits = cameraNode.nodes(at: camLoc)

        if isPausedByPlayer {
            let loc = touch.location(in: pauseOverlay)
            if let action = pauseOverlay.action(at: loc) {
                switch action {
                case .resume:
                    pauseOverlay.removeFromParent()
                    isPausedByPlayer = false
                case .mainMenu:
                    pauseOverlay.removeFromParent()
                    isPausedByPlayer = false
                    endRun(goToMenu: true)
                }
            }
            return
        }

        if camHits.contains(where: { $0.name == HUDOverlay.NodeName.pause }) {
            isPausedByPlayer = true
            pauseOverlay.position = .zero
            pauseOverlay.present(in: cameraNode, sceneSize: size, powerupsTaken: formattedPowerUpCounts())
            return
        }

        if camHits.contains(where: { $0.name == HUDOverlay.NodeName.debugInvincible }) {
            isInvincible.toggle()
            hud.setInvincible(isInvincible)
            return
        }
        if camHits.contains(where: { $0.name == HUDOverlay.NodeName.debugLevelUp }) {
            xpSystem.setLevelForDebug(xpSystem.snapshot().level + 1)
            xpSystem.addPendingLevelUps(1)
            updateHUD()
            return
        }
        if isLevelUpPresented {
            let loc = touch.location(in: levelUpOverlay)
            if let choice = levelUpOverlay.pick(at: loc) {
                applyPowerUp(choice.id)
            }
            return
        }
        updateMoveVector(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isLevelUpPresented else { return }
        updateMoveVector(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isLevelUpPresented else { return }
        moveVector = .zero
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isLevelUpPresented else { return }
        moveVector = .zero
    }

    private func updateMoveVector(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let delta = CGVector(dx: loc.x - player.position.x, dy: loc.y - player.position.y)
        moveVector = normalize(delta)
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard isRunning else { return }
        let dt: CGFloat
        if let lastUpdateTime {
            dt = CGFloat(min(1.0 / 20.0, currentTime - lastUpdateTime))
        } else {
            dt = 0
        }
        lastUpdateTime = currentTime

        elapsed = min(runLengthSeconds, elapsed + TimeInterval(dt))

        if !didVoidSurge, elapsed >= runLengthSeconds {
            didVoidSurge = true
            performVoidSurge()
            bossSystem.spawnBoss(sceneSize: size, playerPosition: player.position)
        }

        if !isLevelUpPresented, !isPausedByPlayer {
            stepPlayer(dt: dt)
            spawner.step(
                dt: dt,
                elapsed: elapsed,
                bossExists: bossSystem.boss != nil,
                sceneSize: size,
                playerPosition: player.position,
                enemies: &enemies
            )
            stepEnemies(dt: dt)
            stepCombat(dt: TimeInterval(dt))
            bossSystem.step(dt: TimeInterval(dt), sceneSize: size, playerPosition: player.position)
            stepRegenAndShield(dt: TimeInterval(dt))
            stepEnemyDots(dt: TimeInterval(dt))
            xpSystem.stepOrbMagnet(dt: TimeInterval(dt), playerPosition: player.position)
        } else {
            cameraNode.position = player.position
        }
        cameraNode.position = player.position
        recycleTilesAroundPlayer()

        if xpSystem.snapshot().pendingLevelUps > 0, !isLevelUpPresented {
            presentLevelUp()
        }

        updateHUD()
    }

    private func stepRegenAndShield(dt: TimeInterval) {
        guard dt > 0 else { return }
        if regenPerSecond > 0, hp > 0 {
            hp = min(maxHP, hp + regenPerSecond * CGFloat(dt))
        }
        if !hasShield {
            shieldRegenRemaining = max(0, shieldRegenRemaining - dt)
            if shieldRegenRemaining <= 0, powerUpStacks[.emberShell, default: 0] > 0 {
                hasShield = true
            }
        }
    }

    private func stepEnemyDots(dt: TimeInterval) {
        if let result = combat.stepDots(dt: dt, enemies: enemies) {
            for e in result.killedEnemies {
                onEnemyKilled(e)
            }
        }
    }

    private func stepPlayer(dt: CGFloat) {
        guard dt > 0 else { return }
        let speed = baseMoveSpeed * moveSpeedMultiplier
        player.position.x += moveVector.dx * speed * dt
        player.position.y += moveVector.dy * speed * dt
    }

    private func stepEnemies(dt: CGFloat) {
        guard dt > 0 else { return }
        for enemy in enemies where !enemy.isHidden {
            let toPlayer = CGVector(dx: player.position.x - enemy.position.x, dy: player.position.y - enemy.position.y)
            let dir = normalize(toPlayer)
            enemy.position.x += dir.dx * enemy.moveSpeed * dt
            enemy.position.y += dir.dy * enemy.moveSpeed * dt
        }
    }

    private func onEnemyKilled(_ enemy: EnemyNode) {
        kills += 1
        if enemy.kind == .scuttler { scuttlerKills += 1 } else { bruteKills += 1 }
        let xpValue = (enemy.kind == .scuttler) ? 4 : 10
        spawnXPOrb(at: enemy.position, value: xpValue)

        combat.tryEruptionFromKill(
            origin: enemy.position,
            enemies: &enemies,
            spawnXPOrb: { [weak self] pos, xp in self?.spawnXPOrb(at: pos, value: xp) },
            onKillCounted: { [weak self] other in
                self?.kills += 1
                if other.kind == .scuttler { self?.scuttlerKills += 1 } else { self?.bruteKills += 1 }
            }
        )

        enemy.isHidden = true
        enemy.removeFromParent()
        enemies.removeAll(where: { $0.parent == nil || $0.isHidden })
        updateHUD()
    }

    private func stepCombat(dt: TimeInterval) {
        if let result = combat.stepRing(
            dt: dt,
            world: world,
            playerPosition: player.position,
            enemies: &enemies,
            boss: bossSystem.boss
        ) {
            for e in result.killedEnemies {
                onEnemyKilled(e)
            }
            if result.bossKilled {
                onBossKilled()
            }
        }
        updateHUD()
    }

    private func performVoidSurge() {
        let flash = SKSpriteNode(color: SKColor(white: 1, alpha: 0.35), size: size)
        flash.zPosition = 9999
        cameraNode.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))

        for e in enemies { e.removeFromParent() }
        enemies.removeAll(keepingCapacity: true)
        xpSystem.clearOrbs()
    }

    private func onBossKilled() {
        bossKilled = true
        endRun()
    }

    private func recycleTilesAroundPlayer() {
        let baseX = floor(player.position.x / tileSize.width) * tileSize.width
        let baseY = floor(player.position.y / tileSize.height) * tileSize.height

        var idx = 0
        for gy in -1...1 {
            for gx in -1...1 {
                tiles[idx].position = CGPoint(
                    x: baseX + CGFloat(gx) * tileSize.width,
                    y: baseY + CGFloat(gy) * tileSize.height
                )
                idx += 1
            }
        }
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        if (a == Physics.player && b == Physics.enemy) || (a == Physics.enemy && b == Physics.player) {
            guard !isInvincible else { return }
            let now = lastUpdateTime ?? 0
            let cooldown: TimeInterval = 0.35
            guard now - lastDamageTime >= cooldown else { return }
            lastDamageTime = now

            let enemyNode = (a == Physics.enemy ? contact.bodyA.node : contact.bodyB.node)
            let dmg = (enemyNode as? EnemyNode)?.contactDamage ?? 6
            applyIncomingDamage(dmg)
            updateHUD()

            if hp <= 0 {
                endRun()
            }
            return
        }

        if (a == Physics.player && b == Physics.xpOrb) || (a == Physics.xpOrb && b == Physics.player) {
            let orbNode = (a == Physics.xpOrb ? contact.bodyA.node : contact.bodyB.node)
            if let orb = orbNode as? XPOrbNode {
                xpSystem.addXP(orb.xpValue)
                orb.removeFromParent()
                xpSystem.onOrbCollected(orb)
                updateHUD()
            }
            return
        }

        if (a == Physics.player && b == Physics.boss) || (a == Physics.boss && b == Physics.player) {
            guard !isInvincible else { return }
            let now = lastUpdateTime ?? 0
            let cooldown: TimeInterval = 0.35
            guard now - lastDamageTime >= cooldown else { return }
            lastDamageTime = now

            let bossNode = (a == Physics.boss ? contact.bodyA.node : contact.bodyB.node)
            let dmg = (bossNode as? BossNode)?.contactDamage ?? 14
            applyIncomingDamage(dmg)
            updateHUD()
            if hp <= 0 {
                endRun()
            }
            return
        }

        if (a == Physics.player && b == Physics.bossAttack) || (a == Physics.bossAttack && b == Physics.player) {
            guard !isInvincible else { return }
            let now = lastUpdateTime ?? 0
            let cooldown: TimeInterval = 0.15
            guard now - lastDamageTime >= cooldown else { return }
            lastDamageTime = now

            applyIncomingDamage(22)
            updateHUD()
            if hp <= 0 {
                endRun()
            }
            return
        }
    }

    private func updateHUD() {
        let xpSnap = xpSystem.snapshot()
        hud.update(
            hp: hp,
            maxHP: maxHP,
            kills: kills,
            enemiesCount: enemies.count,
            level: xpSnap.level,
            xp: xpSnap.xp,
            xpToNext: xpSnap.xpToNext,
            timerText: formatMMSS(seconds: Int(elapsed)),
            boss: bossSystem.boss
        )
    }

    private func applyIncomingDamage(_ rawDamage: CGFloat) {
        guard rawDamage > 0 else { return }

        if hasShield {
            hasShield = false
            shieldRegenRemaining = 15.0
            return
        }

        let reduced = rawDamage * (1 - damageReduction)
        hp = max(0, hp - reduced)

        if hp <= 0, hasRekindle {
            hasRekindle = false
            hp = maxHP * 0.4
        }
    }

    private func formatMMSS(seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func spawnXPOrb(at pos: CGPoint, value: Int) {
        xpSystem.spawnOrb(in: world, at: pos, value: value)
    }

    private func presentLevelUp() {
        isLevelUpPresented = true

        let count = nextLevelCardCountOverride ?? 3
        nextLevelCardCountOverride = nil

        let options = drawPowerUpOptions(count: count)
        if options.isEmpty || (options.count == 1 && options.first == .kindlingBurst) {
            applyOverflowReward()
            xpSystem.consumeOnePendingLevelUp()
            isLevelUpPresented = false
            return
        }

        let choices: [LevelUpOverlay.Choice] = options.map { p in
            .init(id: p.rawValue, title: p.title, subtitle: p.subtitle)
        }

        levelUpOverlay.position = .zero
        levelUpOverlay.present(in: cameraNode, sceneSize: size, choices: choices)
    }

    private func applyPowerUp(_ id: String) {
        guard let p = PowerUpKind(rawValue: id) else { return }
        apply(p)

        // dismiss overlay
        levelUpOverlay.removeFromParent()
        isLevelUpPresented = false
        xpSystem.consumeOnePendingLevelUp()
        updateHUD()
    }

    private func drawPowerUpOptions(count: Int) -> [PowerUpKind] {
        let eligibleWithoutKindling = PowerUpKind.allCases.filter { kind in
            guard kind != .kindlingBurst else { return false }
            return !isPowerUpCapped(kind)
        }

        var eligible = eligibleWithoutKindling
        if !eligibleWithoutKindling.isEmpty, !isPowerUpCapped(.kindlingBurst) {
            eligible.append(.kindlingBurst)
        }

        guard !eligible.isEmpty else { return [] }

        var picked: [PowerUpKind] = []
        var pool = eligible
        while picked.count < count, !pool.isEmpty {
            let idx = Int.random(in: 0..<pool.count)
            picked.append(pool.remove(at: idx))
        }
        return picked
    }

    private func isPowerUpCapped(_ kind: PowerUpKind) -> Bool {
        if kind == .kindlingBurst { return false }
        let stacks = powerUpStacks[kind, default: 0]
        if let cap = kind.maxStacks {
            return stacks >= cap
        }
        return false
    }

    private func apply(_ kind: PowerUpKind) {
        if kind == .kindlingBurst {
            xpSystem.addPendingLevelUps(1)
            return
        }
        if kind == .overload {
            powerUpStacks[kind] = 1
            nextLevelCardCountOverride = 4
            return
        }
        if kind == .ashTithe {
            powerUpStacks[kind] = 1
            ashMultiplier *= 1.5
            return
        }

        let current = powerUpStacks[kind, default: 0]
        let newStacks = current + 1
        powerUpStacks[kind] = newStacks

        switch kind {
        case .scorch:
            combat.damageMultiplier *= 1.2
        case .afterburn:
            combat.burnDps = CGFloat(newStacks) * 5.0
        case .twinFlame:
            combat.damageMultiplier *= 1.35
        case .eruption:
            combat.eruptionChance = (newStacks >= 2) ? 0.50 : 0.25
        case .widerReach:
            combat.attackRadius *= 1.3
        case .rapidCycle:
            combat.attackInterval *= 0.75
        case .emberShell:
            hasShield = true
            shieldRegenRemaining = 0
        case .smoldering:
            regenPerSecond = (newStacks >= 2) ? 10 : 5
        case .ashenHide:
            damageReduction = min(0.30, CGFloat(newStacks) * 0.15)
        case .heatSink:
            maxHP += 30
            hp = min(maxHP, hp + 30)
        case .rekindle:
            hasRekindle = true
        case .draft:
            moveSpeedMultiplier *= 1.2
        case .magneticPull:
            // 1st stack: x2, 2nd stack: x3
            xpSystem.setMagnetStacks(newStacks)
        case .kindlingBurst, .ashTithe, .overload:
            break
        }

        // Cap enforcement: once capped it’s removed from pool via isPowerUpCapped().
        if let cap = kind.maxStacks, newStacks >= cap {
            powerUpStacks[kind] = cap
        }
    }

    private func applyOverflowReward() {
        // Pool exhaustion reward
        maxHP += 15
        hp = min(maxHP, hp + 15)
        combat.damageMultiplier *= 1.10

        let note = SKLabelNode(fontNamed: "AvenirNext-Bold")
        note.text = "MAX BUILD"
        note.fontSize = 18
        note.alpha = 0.0
        note.position = CGPoint(x: 0, y: size.height * 0.15)
        note.zPosition = 9999
        cameraNode.addChild(note)
        note.run(.sequence([.fadeIn(withDuration: 0.12), .wait(forDuration: 0.5), .fadeOut(withDuration: 0.18), .removeFromParent()]))
    }

    private func normalize(_ v: CGVector) -> CGVector {
        let len = sqrt(v.dx * v.dx + v.dy * v.dy)
        guard len > 0.0001 else { return .zero }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }

    private func endRun(goToMenu: Bool = false) {
        guard isRunning else { return }
        isRunning = false

        // Cleanup overlays/hitboxes
        levelUpOverlay.removeFromParent()
        isLevelUpPresented = false
        pauseOverlay.removeFromParent()
        isPausedByPlayer = false

        let timeSurvived = Int(elapsed)
        let ashEarned = computeAshEarned(timeSurvivedSeconds: timeSurvived, bossKilled: bossKilled)

        if goToMenu {
            let scene = MainMenuScene(size: size)
            scene.scaleMode = .resizeFill
            view?.presentScene(scene, transition: .fade(withDuration: 0.25))
            return
        }

        let stats = RunStats(
            timeSurvivedSeconds: timeSurvived,
            kills: kills,
            killsScuttler: scuttlerKills,
            killsBrute: bruteKills,
            finalLevel: xpSystem.snapshot().level,
            ashEarned: ashEarned,
            bossKilled: bossKilled,
            powerUpCounts: powerUpStacks.reduce(into: [:]) { partialResult, kv in
                partialResult[kv.key.title.capitalized] = kv.value
            }
        )
        let scene = RunSummaryScene(size: size, stats: stats)
        scene.scaleMode = .resizeFill
        view?.presentScene(scene, transition: .fade(withDuration: 0.25))
    }

    private func formattedPowerUpCounts() -> [String] {
        guard !powerUpStacks.isEmpty else { return [] }
        return powerUpStacks
            .sorted(by: { $0.key.rawValue < $1.key.rawValue })
            .map { "\($0.key.title.capitalized): \($0.value)" }
    }

    private func computeAshEarned(timeSurvivedSeconds: Int, bossKilled: Bool) -> Int {
        let timeAsh = Int(Double(timeSurvivedSeconds) / 6.0)
        let bossBonus = bossKilled ? 120 : 0
        return Int(Double(timeAsh + bossBonus) * ashMultiplier)
    }
}

