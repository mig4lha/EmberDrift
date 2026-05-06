//
//  PrototypeScene.swift
//  EmberDrift
//
//  Lightweight prototype scene kept for reference.
//  The real game loop lives in `Scripts/Scenes/GameScene.swift`.
//

import SpriteKit

final class PrototypeScene: SKScene, SKPhysicsContactDelegate {
    private enum PhysicsCategory {
        static let player: UInt32 = 1 << 0
        static let enemy: UInt32 = 1 << 1
    }

    private let worldNode = SKNode()
    private let tilesNode = SKNode()
    private let enemiesNode = SKNode()

    private let cameraNode = SKCameraNode()

    private let tileSize = CGSize(width: 512, height: 512)
    private var tiles: [SKSpriteNode] = []

    private let player = SKShapeNode(circleOfRadius: 22)
    private var desiredMoveVector = CGVector(dx: 0, dy: 0)
    private let playerSpeed: CGFloat = 260

    private let scuttler = SKShapeNode(circleOfRadius: 18)
    private let scuttlerSpeed: CGFloat = 140

    private var lastUpdateTime: TimeInterval?
    private var lastContactDamageTime: TimeInterval = 0
    private var playerHP: CGFloat = 100

    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    override func didMove(to view: SKView) {
        backgroundColor = .black

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        addChild(worldNode)
        worldNode.addChild(tilesNode)
        worldNode.addChild(enemiesNode)

        setupCamera()
        setupHUD()
        setupTiles()
        setupPlayer()
        setupScuttler()
        updateHUD()
    }

    private func setupCamera() {
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = .zero
    }

    private func setupHUD() {
        hpLabel.fontSize = 18
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.verticalAlignmentMode = .top
        hpLabel.position = CGPoint(x: -size.width * 0.5 + 16, y: size.height * 0.5 - 16)
        hpLabel.zPosition = 10_000
        cameraNode.addChild(hpLabel)
    }

    private func setupTiles() {
        tiles.removeAll(keepingCapacity: true)
        tilesNode.removeAllChildren()

        for gy in -1...1 {
            for gx in -1...1 {
                let tile = SKSpriteNode(color: (gx + gy).isMultiple(of: 2) ? .darkGray : .gray, size: tileSize)
                tile.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                tile.position = CGPoint(x: CGFloat(gx) * tileSize.width, y: CGFloat(gy) * tileSize.height)
                tile.zPosition = -100
                tilesNode.addChild(tile)
                tiles.append(tile)
            }
        }
    }

    private func setupPlayer() {
        player.fillColor = .orange
        player.strokeColor = .clear
        player.position = .zero
        player.zPosition = 10

        let body = SKPhysicsBody(circleOfRadius: 22)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.isDynamic = true
        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.enemy
        body.collisionBitMask = 0
        player.physicsBody = body

        worldNode.addChild(player)
    }

    private func setupScuttler() {
        scuttler.fillColor = .cyan
        scuttler.strokeColor = .clear
        scuttler.position = CGPoint(x: 200, y: 0)
        scuttler.zPosition = 10

        let body = SKPhysicsBody(circleOfRadius: 18)
        body.affectedByGravity = false
        body.allowsRotation = false
        body.isDynamic = true
        body.categoryBitMask = PhysicsCategory.enemy
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = 0
        scuttler.physicsBody = body

        enemiesNode.addChild(scuttler)
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateDesiredMoveVector(from: touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateDesiredMoveVector(from: touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        desiredMoveVector = .zero
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        desiredMoveVector = .zero
    }

    private func updateDesiredMoveVector(from touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let delta = CGVector(dx: location.x - player.position.x, dy: location.y - player.position.y)
        desiredMoveVector = normalize(delta)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat
        if let last = lastUpdateTime {
            dt = CGFloat(min(1.0 / 20.0, currentTime - last))
        } else {
            dt = 0
        }
        lastUpdateTime = currentTime

        stepPlayer(dt: dt)
        stepEnemy(dt: dt)
        stepCamera()
        recycleTilesAroundPlayer()
    }

    private func stepPlayer(dt: CGFloat) {
        guard dt > 0 else { return }
        player.position.x += desiredMoveVector.dx * playerSpeed * dt
        player.position.y += desiredMoveVector.dy * playerSpeed * dt
    }

    private func stepEnemy(dt: CGFloat) {
        guard dt > 0 else { return }
        let toPlayer = CGVector(dx: player.position.x - scuttler.position.x, dy: player.position.y - scuttler.position.y)
        let dir = normalize(toPlayer)
        scuttler.position.x += dir.dx * scuttlerSpeed * dt
        scuttler.position.y += dir.dy * scuttlerSpeed * dt
    }

    private func stepCamera() {
        cameraNode.position = player.position
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

    // MARK: - Contacts (Week 1: basic contact damage)

    func didBegin(_ contact: SKPhysicsContact) {
        applyContactDamageIfNeeded(at: lastUpdateTime ?? 0)
    }

    func didEnd(_ contact: SKPhysicsContact) {
        // no-op
    }

    private func applyContactDamageIfNeeded(at time: TimeInterval) {
        let damageCooldown: TimeInterval = 0.35
        guard time - lastContactDamageTime >= damageCooldown else { return }
        lastContactDamageTime = time

        let damage: CGFloat = 6
        playerHP = max(0, playerHP - damage)
        updateHUD()

        if playerHP <= 0 {
            onPlayerDied()
        }
    }

    private func onPlayerDied() {
        isPaused = true
        hpLabel.text = "HP: 0 (dead)"
    }

    private func updateHUD() {
        hpLabel.text = "HP: \(Int(playerHP))"
    }

    private func normalize(_ v: CGVector) -> CGVector {
        let len = sqrt(v.dx * v.dx + v.dy * v.dy)
        guard len > 0.0001 else { return .zero }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }
}

