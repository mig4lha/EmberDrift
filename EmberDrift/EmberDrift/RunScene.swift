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

    private var spawnAccumulator: CGFloat = 0

    // Run timer
    private var elapsed: TimeInterval = 0
    private let runLengthSeconds: TimeInterval = 300
    private var didVoidSurge: Bool = false

    // Auto-attack (Ember Ring)
    private var attackCooldownRemaining: TimeInterval = 0
    private var attackInterval: TimeInterval = 1.2
    private var attackRadius: CGFloat = 120
    private let baseAttackDamage: CGFloat = 8
    private var damageMultiplier: CGFloat = 1.0
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

    // Afterburn + eruption
    private var burnDps: CGFloat = 0.0
    private let burnDuration: TimeInterval = 3.0
    private var eruptionChance: Double = 0.0

    // XP + leveling
    private var level: Int = 1
    private var xp: Int = 0
    private var pendingLevelUps: Int = 0
    private var isLevelUpPresented: Bool = false
    private let levelUpOverlay = LevelUpOverlay()
    private var xpOrbs: [XPOrbNode] = []
    private let baseOrbPullRadius: CGFloat = 90
    private var orbPullRadiusMultiplier: CGFloat = 1.0

    // Power-ups (GDD)
    private var powerUpStacks: [PowerUpKind: Int] = [:]

    // HUD
    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statsLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let xpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let timerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let bossBarBG = SKShapeNode(rectOf: CGSize(width: 220, height: 12), cornerRadius: 6)
    private let bossBarFill = SKShapeNode(rectOf: CGSize(width: 216, height: 8), cornerRadius: 4)
    private let bossLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let debugInvLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let debugLevelLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let pauseLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var hp: CGFloat = 100
    private var lastDamageTime: TimeInterval = -999

    private var lastUpdateTime: TimeInterval?

    // Boss
    private var boss: BossNode?
    private var bossPhase2: Bool = false
    private var stompCooldownRemaining: TimeInterval = 0

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

        setupTiles()
        setupPlayer()
        // spawn is continuous now
        setupHUD()
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

    private func setupHUD() {
        hpLabel.fontSize = 18
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.verticalAlignmentMode = .top
        hpLabel.zPosition = 10_000
        cameraNode.addChild(hpLabel)

        statsLabel.fontSize = 14
        statsLabel.horizontalAlignmentMode = .left
        statsLabel.verticalAlignmentMode = .top
        statsLabel.alpha = 0.85
        statsLabel.zPosition = 10_000
        cameraNode.addChild(statsLabel)

        xpLabel.fontSize = 14
        xpLabel.horizontalAlignmentMode = .left
        xpLabel.verticalAlignmentMode = .top
        xpLabel.alpha = 0.85
        xpLabel.zPosition = 10_000
        cameraNode.addChild(xpLabel)

        timerLabel.fontSize = 18
        timerLabel.horizontalAlignmentMode = .right
        timerLabel.verticalAlignmentMode = .top
        timerLabel.zPosition = 10_000
        cameraNode.addChild(timerLabel)

        bossLabel.text = "VOID COLOSSUS"
        bossLabel.fontSize = 14
        bossLabel.alpha = 0.9
        bossLabel.isHidden = true
        bossLabel.zPosition = 10_000
        cameraNode.addChild(bossLabel)

        bossBarBG.fillColor = SKColor(white: 0.1, alpha: 0.85)
        bossBarBG.strokeColor = SKColor(white: 1, alpha: 0.15)
        bossBarBG.lineWidth = 2
        bossBarBG.isHidden = true
        bossBarBG.zPosition = 10_000
        cameraNode.addChild(bossBarBG)

        bossBarFill.fillColor = .systemRed
        bossBarFill.strokeColor = .clear
        bossBarFill.isHidden = true
        bossBarFill.zPosition = 10_001
        cameraNode.addChild(bossBarFill)

        debugInvLabel.text = "INV: OFF"
        debugInvLabel.fontSize = 14
        debugInvLabel.alpha = 0.85
        debugInvLabel.name = "debug_inv"
        debugInvLabel.horizontalAlignmentMode = .right
        debugInvLabel.verticalAlignmentMode = .top
        debugInvLabel.zPosition = 10_000
        cameraNode.addChild(debugInvLabel)

        debugLevelLabel.text = "+LVL"
        debugLevelLabel.fontSize = 14
        debugLevelLabel.alpha = 0.85
        debugLevelLabel.name = "debug_lvl"
        debugLevelLabel.horizontalAlignmentMode = .right
        debugLevelLabel.verticalAlignmentMode = .top
        debugLevelLabel.zPosition = 10_000
        cameraNode.addChild(debugLevelLabel)

        pauseLabel.text = "PAUSE"
        pauseLabel.fontSize = 14
        pauseLabel.alpha = 0.9
        pauseLabel.name = "hud_pause"
        pauseLabel.horizontalAlignmentMode = .right
        pauseLabel.verticalAlignmentMode = .top
        pauseLabel.zPosition = 10_000
        cameraNode.addChild(pauseLabel)

        layoutHUD()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    private func layoutHUD() {
        hpLabel.position = CGPoint(x: -size.width * 0.5 + 16, y: size.height * 0.5 - 16)
        statsLabel.position = CGPoint(x: -size.width * 0.5 + 16, y: size.height * 0.5 - 40)
        xpLabel.position = CGPoint(x: -size.width * 0.5 + 16, y: size.height * 0.5 - 64)
        timerLabel.position = CGPoint(x: size.width * 0.5 - 16, y: size.height * 0.5 - 16)

        bossLabel.position = CGPoint(x: 0, y: size.height * 0.5 - 20)
        bossBarBG.position = CGPoint(x: 0, y: size.height * 0.5 - 40)
        bossBarFill.position = bossBarBG.position

        debugInvLabel.position = CGPoint(x: size.width * 0.5 - 16, y: size.height * 0.5 - 40)
        debugLevelLabel.position = CGPoint(x: size.width * 0.5 - 16, y: size.height * 0.5 - 64)
        pauseLabel.position = CGPoint(x: size.width * 0.5 - 16, y: size.height * 0.5 - 88)
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

        if camHits.contains(where: { $0.name == "hud_pause" }) {
            isPausedByPlayer = true
            pauseOverlay.position = .zero
            pauseOverlay.present(in: cameraNode, sceneSize: size, powerupsTaken: formattedPowerUpCounts())
            return
        }

        if camHits.contains(where: { $0.name == "debug_inv" }) {
            isInvincible.toggle()
            debugInvLabel.text = isInvincible ? "INV: ON" : "INV: OFF"
            return
        }
        if camHits.contains(where: { $0.name == "debug_lvl" }) {
            level += 1
            pendingLevelUps += 1
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
            spawnBoss()
        }

        if !isLevelUpPresented, !isPausedByPlayer {
            stepPlayer(dt: dt)
            spawnEnemies(dt: dt)
            stepEnemies(dt: dt)
            stepCombat(dt: TimeInterval(dt))
            stepBoss(dt: TimeInterval(dt))
            stepRegenAndShield(dt: TimeInterval(dt))
            stepEnemyDots(dt: TimeInterval(dt))
            stepOrbMagnet(dt: TimeInterval(dt))
        } else {
            cameraNode.position = player.position
        }
        cameraNode.position = player.position
        recycleTilesAroundPlayer()

        if pendingLevelUps > 0, !isLevelUpPresented {
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
        // Placeholder DoT ticks; implemented by attaching values to userData.
        guard dt > 0, burnDps > 0 else { return }
        for enemy in enemies where !enemy.isHidden {
            guard let ud = enemy.userData else { continue }
            let remaining = (ud["burnRemaining"] as? Double) ?? 0
            if remaining <= 0 { continue }
            let newRemaining = max(0, remaining - dt)
            ud["burnRemaining"] = newRemaining
            enemy.hp = max(0, enemy.hp - burnDps * CGFloat(dt))
            if enemy.hp <= 0 {
                onEnemyKilled(enemy)
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

        // Eruption: chance to deal AoE on kill
        if eruptionChance > 0, Double.random(in: 0...1) < eruptionChance {
            let radius: CGFloat = 95
            let dmg = baseAttackDamage * damageMultiplier * 1.2
            let r2 = radius * radius
            for other in enemies where !other.isHidden {
                let dx = other.position.x - enemy.position.x
                let dy = other.position.y - enemy.position.y
                if (dx * dx + dy * dy) <= r2 {
                    other.hp = max(0, other.hp - dmg)
                    if other.hp <= 0 {
                        // avoid recursion explosion; mark and clean later
                        other.isHidden = true
                        other.removeFromParent()
                        kills += 1
                        if other.kind == .scuttler { scuttlerKills += 1 } else { bruteKills += 1 }
                        let xp2 = (other.kind == .scuttler) ? 4 : 10
                        spawnXPOrb(at: other.position, value: xp2)
                    }
                }
            }
        }

        enemy.isHidden = true
        enemy.removeFromParent()
        enemies.removeAll(where: { $0.parent == nil || $0.isHidden })
        updateHUD()
    }

    private func spawnEnemies(dt: CGFloat) {
        guard dt > 0 else { return }
        // Stop spawns at 4:45 per GDD (void surge prep)
        let spawningEnabled = elapsed < 285
        guard spawningEnabled else { return }
        guard boss == nil else { return }

        spawnAccumulator += spawnRate(elapsedSeconds: elapsed) * dt
        while spawnAccumulator >= 1 {
            spawnAccumulator -= 1
            spawnOneEnemy()
        }
    }

    private func spawnOneEnemy() {
        // Brutes are introduced at 1:00.
        let hasBrutes = elapsed >= 60
        let shouldSpawnBrute = hasBrutes && Double.random(in: 0...1) < 0.22
        if shouldSpawnBrute {
            spawnBrute()
        } else {
            spawnScuttler()
        }
    }

    private func spawnScuttler() {
        let enemy = EnemyNode(
            kind: .scuttler,
            radius: scuttlerRadius,
            maxHP: scuttlerHP,
            moveSpeed: scuttlerSpeed,
            contactDamage: scuttlerContactDamage
        )
        enemy.position = spawnPointOutsideCamera()
        world.addChild(enemy)
        enemies.append(enemy)
    }

    private func spawnBrute() {
        let enemy = EnemyNode(
            kind: .brute,
            radius: bruteRadius,
            maxHP: bruteHP,
            moveSpeed: bruteSpeed,
            contactDamage: bruteContactDamage
        )
        enemy.position = spawnPointOutsideCamera()
        world.addChild(enemy)
        enemies.append(enemy)
    }

    private func spawnRate(elapsedSeconds t: TimeInterval) -> CGFloat {
        // Continuous curve approximating the design table.
        // 0:00 2/s → 1:00 4/s → 2:00 7/s → 3:00 11/s → 4:00 16/s
        func lerp(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat { a + (b - a) * x }
        func segment(_ t0: TimeInterval, _ t1: TimeInterval, _ r0: CGFloat, _ r1: CGFloat, _ t: TimeInterval) -> CGFloat {
            let x = CGFloat((t - t0) / max(0.0001, (t1 - t0)))
            return lerp(r0, r1, max(0, min(1, x)))
        }

        if t < 60 { return segment(0, 60, 2, 4, t) }
        if t < 120 { return segment(60, 120, 4, 7, t) }
        if t < 180 { return segment(120, 180, 7, 11, t) }
        if t < 240 { return segment(180, 240, 11, 16, t) }
        return 16
    }

    private func spawnPointOutsideCamera() -> CGPoint {
        // Spawn just outside visible area around the camera/player.
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let margin: CGFloat = 40

        let side = Int.random(in: 0..<4)
        switch side {
        case 0: // left
            return CGPoint(x: player.position.x - halfW - margin, y: player.position.y + CGFloat.random(in: -halfH...halfH))
        case 1: // right
            return CGPoint(x: player.position.x + halfW + margin, y: player.position.y + CGFloat.random(in: -halfH...halfH))
        case 2: // bottom
            return CGPoint(x: player.position.x + CGFloat.random(in: -halfW...halfW), y: player.position.y - halfH - margin)
        default: // top
            return CGPoint(x: player.position.x + CGFloat.random(in: -halfW...halfW), y: player.position.y + halfH + margin)
        }
    }

    private func stepCombat(dt: TimeInterval) {
        guard dt > 0 else { return }
        attackCooldownRemaining -= dt
        guard attackCooldownRemaining <= 0 else { return }
        attackCooldownRemaining = attackInterval

        // Visual ring
        let ring = SKShapeNode(circleOfRadius: attackRadius)
        ring.position = player.position
        ring.strokeColor = SKColor(white: 1, alpha: 0.65)
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.zPosition = 100
        world.addChild(ring)
        ring.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))

        // Damage all enemies in radius
        let radiusSq = attackRadius * attackRadius
        for enemy in enemies where !enemy.isHidden {
            let dx = enemy.position.x - player.position.x
            let dy = enemy.position.y - player.position.y
            if (dx * dx + dy * dy) <= radiusSq {
                let dmg = baseAttackDamage * damageMultiplier
                enemy.hp = max(0, enemy.hp - dmg)

                // Afterburn: apply burn DoT
                if burnDps > 0 {
                    if enemy.userData == nil { enemy.userData = NSMutableDictionary() }
                    enemy.userData?["burnRemaining"] = burnDuration
                }
                if enemy.hp <= 0 {
                    onEnemyKilled(enemy)
                }
            }
        }

        // Keep list small
        enemies.removeAll(where: { $0.parent == nil || $0.isHidden })

        // Boss takes damage from Ember Ring too.
        if let boss, boss.hp > 0 {
            let dx = boss.position.x - player.position.x
            let dy = boss.position.y - player.position.y
            if (dx * dx + dy * dy) <= radiusSq {
                let dmg = baseAttackDamage * damageMultiplier
                boss.hp = max(0, boss.hp - dmg)
                if boss.hp <= 0 {
                    onBossKilled()
                }
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

        // Optional cleanup: remove orbs during surge (keeps boss arena clean).
        for orb in xpOrbs { orb.removeFromParent() }
        xpOrbs.removeAll(keepingCapacity: true)
    }

    private func spawnBoss() {
        let node = BossNode(radius: 34, maxHP: 520, moveSpeed: 70, contactDamage: 16)
        node.position = bossSpawnPoint()
        world.addChild(node)
        boss = node
        bossPhase2 = false
        stompCooldownRemaining = 2.2
        bossLabel.isHidden = false
        bossBarBG.isHidden = false
        bossBarFill.isHidden = false
        updateHUD()
    }

    private func bossSpawnPoint() -> CGPoint {
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        let margin: CGFloat = 30
        let side = Int.random(in: 0..<4)
        switch side {
        case 0: return CGPoint(x: player.position.x - halfW - margin, y: player.position.y)
        case 1: return CGPoint(x: player.position.x + halfW + margin, y: player.position.y)
        case 2: return CGPoint(x: player.position.x, y: player.position.y - halfH - margin)
        default: return CGPoint(x: player.position.x, y: player.position.y + halfH + margin)
        }
    }

    private func stepBoss(dt: TimeInterval) {
        guard dt > 0, let boss, boss.hp > 0 else { return }

        if !bossPhase2, boss.hp <= boss.maxHP * 0.5 {
            bossPhase2 = true
            let flash = SKSpriteNode(color: SKColor(white: 1, alpha: 0.22), size: size)
            flash.zPosition = 9999
            cameraNode.addChild(flash)
            flash.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
            boss.setScale(1.08)
            stompCooldownRemaining = 1.0
        }

        if bossPhase2 {
            stompCooldownRemaining -= dt
            if stompCooldownRemaining <= 0 {
                stompCooldownRemaining = 4.0
                performVoidStomp(from: boss)
            }
        }

        let toPlayer = CGVector(dx: player.position.x - boss.position.x, dy: player.position.y - boss.position.y)
        let dir = normalize(toPlayer)
        boss.position.x += dir.dx * boss.moveSpeed * CGFloat(dt)
        boss.position.y += dir.dy * boss.moveSpeed * CGFloat(dt)
    }

    private func performVoidStomp(from boss: BossNode) {
        let tell = SKShapeNode(circleOfRadius: 46)
        tell.position = boss.position
        tell.fillColor = SKColor(white: 1, alpha: 0.08)
        tell.strokeColor = SKColor(white: 1, alpha: 0.22)
        tell.lineWidth = 2
        tell.zPosition = 80
        world.addChild(tell)
        tell.run(.sequence([.scale(to: 1.25, duration: 0.25), .fadeOut(withDuration: 0.2), .removeFromParent()]))

        run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in
            self?.spawnStompShockwaves(at: boss.position)
        }]))
    }

    private func spawnStompShockwaves(at origin: CGPoint) {
        let duration: TimeInterval = 0.6
        let thickness: CGFloat = 26
        let maxLen = max(size.width, size.height) * 1.2
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
            body.categoryBitMask = Physics.bossAttack
            body.collisionBitMask = Physics.none
            body.contactTestBitMask = Physics.player
            node.physicsBody = body
            return node
        }

        let h = makeWave(rotation: 0)
        let v = makeWave(rotation: .pi / 2)
        world.addChild(h)
        world.addChild(v)

        let expand = SKAction.customAction(withDuration: duration) { node, t in
            let p = t / CGFloat(duration)
            let w = startLen + (maxLen - startLen) * p
            let rect = CGRect(x: -w / 2, y: -thickness / 2, width: w, height: thickness)
            (node as? SKShapeNode)?.path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)

            let body = SKPhysicsBody(rectangleOf: CGSize(width: w, height: thickness))
            body.affectedByGravity = false
            body.allowsRotation = false
            body.isDynamic = false
            body.categoryBitMask = Physics.bossAttack
            body.collisionBitMask = Physics.none
            body.contactTestBitMask = Physics.player
            node.physicsBody = body
        }

        h.run(.sequence([expand, .removeFromParent()]))
        v.run(.sequence([expand, .removeFromParent()]))
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
                collectXP(orb.xpValue)
                orb.removeFromParent()
                xpOrbs.removeAll(where: { $0 === orb })
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
        hpLabel.text = "HP: \(Int(hp))/\(Int(maxHP))"
        statsLabel.text = "Kills: \(kills)   Enemies: \(enemies.count)"
        xpLabel.text = "Level: \(level)   XP: \(xp)/\(xpNeededForNextLevel())"
        timerLabel.text = formatMMSS(seconds: Int(elapsed))

        if let boss {
            let pct = max(0, min(1, boss.hp / max(1, boss.maxHP)))
            bossBarFill.xScale = pct
            bossBarFill.isHidden = false
            bossBarBG.isHidden = false
            bossLabel.isHidden = false
        }
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
        let orb = XPOrbNode(xpValue: value)
        orb.position = pos
        world.addChild(orb)
        xpOrbs.append(orb)
    }

    private func collectXP(_ amount: Int) {
        xp += amount
        while xp >= xpNeededForNextLevel() {
            xp -= xpNeededForNextLevel()
            level += 1
            pendingLevelUps += 1
        }
        updateHUD()
    }

    private func stepOrbMagnet(dt: TimeInterval) {
        guard dt > 0 else { return }
        let pullRadius = baseOrbPullRadius * orbPullRadiusMultiplier
        let pullRadiusSq = pullRadius * pullRadius
        let pullSpeed: CGFloat = 520 // world units/sec; tuned feel

        // prune collected/deleted orbs
        xpOrbs.removeAll(where: { $0.parent == nil })

        for orb in xpOrbs {
            let dx = player.position.x - orb.position.x
            let dy = player.position.y - orb.position.y
            let distSq = dx * dx + dy * dy
            guard distSq <= pullRadiusSq, distSq > 0.0001 else { continue }
            let dist = sqrt(distSq)
            let step = min(dist, pullSpeed * CGFloat(dt))
            orb.position.x += (dx / dist) * step
            orb.position.y += (dy / dist) * step
        }
    }

    private func xpNeededForNextLevel() -> Int {
        // Front-loaded curve (MVP baseline)
        switch level {
        case 1: return 20
        case 2: return 35
        case 3: return 55
        case 4: return 80
        case 5: return 110
        case 6: return 145
        case 7: return 185
        case 8: return 230
        case 9: return 280
        default:
            // small ramp beyond 10
            return 280 + (level - 9) * 60
        }
    }

    private func presentLevelUp() {
        isLevelUpPresented = true

        let count = nextLevelCardCountOverride ?? 3
        nextLevelCardCountOverride = nil

        let options = drawPowerUpOptions(count: count)
        if options.isEmpty || (options.count == 1 && options.first == .kindlingBurst) {
            applyOverflowReward()
            pendingLevelUps = max(0, pendingLevelUps - 1)
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
        pendingLevelUps = max(0, pendingLevelUps - 1)
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
            pendingLevelUps += 1
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
            damageMultiplier *= 1.2
        case .afterburn:
            burnDps = CGFloat(newStacks) * 5.0
        case .twinFlame:
            damageMultiplier *= 1.35
        case .eruption:
            eruptionChance = (newStacks >= 2) ? 0.50 : 0.25
        case .widerReach:
            attackRadius *= 1.3
        case .rapidCycle:
            attackInterval *= 0.75
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
            orbPullRadiusMultiplier = (newStacks >= 2) ? 3.0 : 2.0
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
        damageMultiplier *= 1.10

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
            finalLevel: level,
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

