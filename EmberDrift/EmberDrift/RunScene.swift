import SpriteKit

final class RunScene: SKScene, SKPhysicsContactDelegate {
    enum Physics {
        static let none: UInt32 = 0
        static let player: UInt32 = 1 << 0
        static let enemy: UInt32 = 1 << 1
        static let xpOrb: UInt32 = 1 << 2
    }

    private let world = SKNode()
    private let cameraNode = SKCameraNode()

    // Map tiling (3x3)
    private let tileSize = CGSize(width: 512, height: 512)
    private var tiles: [SKSpriteNode] = []

    // Player
    private let player = SKShapeNode(circleOfRadius: 18)
    private var moveVector = CGVector(dx: 0, dy: 0) // normalized
    private let baseMoveSpeed: CGFloat = 260
    private var moveSpeedMultiplier: CGFloat = 1.0

    // Enemies
    private var enemies: [EnemyNode] = []
    private let scuttlerRadius: CGFloat = 16
    private let scuttlerSpeed: CGFloat = 140
    private let scuttlerHP: CGFloat = 16

    private var spawnAccumulator: CGFloat = 0
    private let spawnRatePerSecond: CGFloat = 2.0

    // Auto-attack (Ember Ring)
    private var attackCooldownRemaining: TimeInterval = 0
    private var attackInterval: TimeInterval = 1.2
    private var attackRadius: CGFloat = 120
    private var attackDamage: CGFloat = 8
    private var kills: Int = 0

    // XP + leveling
    private var level: Int = 1
    private var xp: Int = 0
    private var pendingLevelUps: Int = 0
    private var isLevelUpPresented: Bool = false
    private let levelUpOverlay = LevelUpOverlay()

    enum PowerUp: String, CaseIterable {
        case scorch
        case widerReach
        case rapidCycle
        case draft
    }

    // HUD
    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statsLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let xpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private var hp: CGFloat = 100
    private var lastDamageTime: TimeInterval = -999

    private var lastUpdateTime: TimeInterval?

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
                let tile = SKSpriteNode(
                    color: (gx + gy).isMultiple(of: 2) ? .darkGray : .gray,
                    size: tileSize
                )
                tile.zPosition = -100
                tile.position = CGPoint(x: CGFloat(gx) * tileSize.width, y: CGFloat(gy) * tileSize.height)
                world.addChild(tile)
                tiles.append(tile)
            }
        }
    }

    private func setupPlayer() {
        player.fillColor = .systemOrange
        player.strokeColor = .clear
        player.position = .zero
        player.zPosition = 10

        let body = SKPhysicsBody(circleOfRadius: 18)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = Physics.player
        body.collisionBitMask = Physics.none
        body.contactTestBitMask = Physics.enemy | Physics.xpOrb
        player.physicsBody = body

        world.addChild(player)
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
    }

    // MARK: - Touch movement (Week 1)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
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
        let dt: CGFloat
        if let lastUpdateTime {
            dt = CGFloat(min(1.0 / 20.0, currentTime - lastUpdateTime))
        } else {
            dt = 0
        }
        lastUpdateTime = currentTime

        if !isLevelUpPresented {
            stepPlayer(dt: dt)
            spawnEnemies(dt: dt)
            stepEnemies(dt: dt)
            stepCombat(dt: TimeInterval(dt))
        } else {
            cameraNode.position = player.position
        }
        cameraNode.position = player.position
        recycleTilesAroundPlayer()

        if pendingLevelUps > 0, !isLevelUpPresented {
            presentLevelUp()
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

    private func spawnEnemies(dt: CGFloat) {
        guard dt > 0 else { return }
        spawnAccumulator += spawnRatePerSecond * dt
        while spawnAccumulator >= 1 {
            spawnAccumulator -= 1
            spawnScuttler()
        }
    }

    private func spawnScuttler() {
        let enemy = EnemyNode(radius: scuttlerRadius, maxHP: scuttlerHP, moveSpeed: scuttlerSpeed)
        enemy.position = spawnPointOutsideCamera()
        world.addChild(enemy)
        enemies.append(enemy)
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
                enemy.hp = max(0, enemy.hp - attackDamage)
                if enemy.hp <= 0 {
                    kills += 1
                    spawnXPOrb(at: enemy.position, value: 4)
                    enemy.isHidden = true
                    enemy.removeFromParent()
                }
            }
        }

        // Keep list small
        enemies.removeAll(where: { $0.parent == nil || $0.isHidden })
        updateHUD()
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
            let now = lastUpdateTime ?? 0
            let cooldown: TimeInterval = 0.35
            guard now - lastDamageTime >= cooldown else { return }
            lastDamageTime = now

            hp = max(0, hp - 6)
            updateHUD()

            if hp <= 0 {
                isPaused = true
                hpLabel.text = "HP: 0 (dead)"
            }
            return
        }

        if (a == Physics.player && b == Physics.xpOrb) || (a == Physics.xpOrb && b == Physics.player) {
            let orbNode = (a == Physics.xpOrb ? contact.bodyA.node : contact.bodyB.node)
            if let orb = orbNode as? XPOrbNode {
                collectXP(orb.xpValue)
                orb.removeFromParent()
            }
            return
        }
    }

    private func updateHUD() {
        hpLabel.text = "HP: \(Int(hp))"
        statsLabel.text = "Kills: \(kills)   Enemies: \(enemies.count)"
        xpLabel.text = "Level: \(level)   XP: \(xp)/\(xpNeededForNextLevel())"
    }

    private func spawnXPOrb(at pos: CGPoint, value: Int) {
        let orb = XPOrbNode(xpValue: value)
        orb.position = pos
        world.addChild(orb)
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

        var options = Array(PowerUp.allCases.shuffled().prefix(3))
        if options.count < 3 { options = Array(PowerUp.allCases.prefix(3)) }

        let choices: [LevelUpOverlay.Choice] = options.map { p in
            switch p {
            case .scorch:
                return .init(id: p.rawValue, title: "SCORCH", subtitle: "+20% damage")
            case .widerReach:
                return .init(id: p.rawValue, title: "WIDER REACH", subtitle: "+30% attack radius")
            case .rapidCycle:
                return .init(id: p.rawValue, title: "RAPID CYCLE", subtitle: "Attack faster")
            case .draft:
                return .init(id: p.rawValue, title: "DRAFT", subtitle: "+20% move speed")
            }
        }

        levelUpOverlay.position = .zero
        levelUpOverlay.present(in: cameraNode, sceneSize: size, choices: choices)
    }

    private func applyPowerUp(_ id: String) {
        guard let p = PowerUp(rawValue: id) else { return }
        switch p {
        case .scorch:
            attackDamage *= 1.2
        case .widerReach:
            attackRadius *= 1.3
        case .rapidCycle:
            attackInterval *= 0.85
        case .draft:
            moveSpeedMultiplier *= 1.2
        }

        // dismiss overlay
        levelUpOverlay.removeFromParent()
        isLevelUpPresented = false
        pendingLevelUps = max(0, pendingLevelUps - 1)
        updateHUD()
    }

    private func normalize(_ v: CGVector) -> CGVector {
        let len = sqrt(v.dx * v.dx + v.dy * v.dy)
        guard len > 0.0001 else { return .zero }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }
}

