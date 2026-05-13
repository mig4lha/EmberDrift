import SpriteKit

final class HUDOverlay {
    enum NodeName {
        static let pause = "hud_pause"
        static let debugInvincible = "debug_inv"
        static let debugLevelUp = "debug_lvl"
    }

    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statsLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let xpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let timerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let bossLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let bossBarBG = SKShapeNode(rectOf: CGSize(width: 220, height: 12), cornerRadius: 6)
    private let bossBarFill = SKShapeNode(rectOf: CGSize(width: 216, height: 8), cornerRadius: 4)

    private let debugInvLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let debugLevelLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let pauseLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    func attach(to cameraNode: SKNode) {
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
        debugInvLabel.name = NodeName.debugInvincible
        debugInvLabel.horizontalAlignmentMode = .right
        debugInvLabel.verticalAlignmentMode = .top
        debugInvLabel.zPosition = 10_000
        cameraNode.addChild(debugInvLabel)

        debugLevelLabel.text = "+LVL"
        debugLevelLabel.fontSize = 14
        debugLevelLabel.alpha = 0.85
        debugLevelLabel.name = NodeName.debugLevelUp
        debugLevelLabel.horizontalAlignmentMode = .right
        debugLevelLabel.verticalAlignmentMode = .top
        debugLevelLabel.zPosition = 10_000
        cameraNode.addChild(debugLevelLabel)

        pauseLabel.text = "PAUSE"
        pauseLabel.fontSize = 14
        pauseLabel.alpha = 0.9
        pauseLabel.name = NodeName.pause
        pauseLabel.horizontalAlignmentMode = .right
        pauseLabel.verticalAlignmentMode = .top
        pauseLabel.zPosition = 10_000
        cameraNode.addChild(pauseLabel)
    }

    func layout(sceneSize: CGSize) {
        hpLabel.position = CGPoint(x: -sceneSize.width * 0.5 + 16, y: sceneSize.height * 0.5 - 16)
        statsLabel.position = CGPoint(x: -sceneSize.width * 0.5 + 16, y: sceneSize.height * 0.5 - 40)
        xpLabel.position = CGPoint(x: -sceneSize.width * 0.5 + 16, y: sceneSize.height * 0.5 - 64)
        timerLabel.position = CGPoint(x: sceneSize.width * 0.5 - 16, y: sceneSize.height * 0.5 - 16)

        bossLabel.position = CGPoint(x: 0, y: sceneSize.height * 0.5 - 20)
        bossBarBG.position = CGPoint(x: 0, y: sceneSize.height * 0.5 - 40)
        bossBarFill.position = bossBarBG.position

        debugInvLabel.position = CGPoint(x: sceneSize.width * 0.5 - 16, y: sceneSize.height * 0.5 - 40)
        debugLevelLabel.position = CGPoint(x: sceneSize.width * 0.5 - 16, y: sceneSize.height * 0.5 - 64)
        pauseLabel.position = CGPoint(x: sceneSize.width * 0.5 - 16, y: sceneSize.height * 0.5 - 88)
    }

    func setInvincible(_ on: Bool) {
        debugInvLabel.text = on ? "INV: ON" : "INV: OFF"
    }

    func update(
        hp: CGFloat,
        maxHP: CGFloat,
        kills: Int,
        enemiesCount: Int,
        level: Int,
        xp: Int,
        xpToNext: Int,
        timerText: String,
        boss: BossNode?
    ) {
        hpLabel.text = "HP: \(Int(hp))/\(Int(maxHP))"
        statsLabel.text = "Kills: \(kills)   Enemies: \(enemiesCount)"
        xpLabel.text = "Level: \(level)   XP: \(xp)/\(xpToNext)"
        timerLabel.text = timerText

        if let boss {
            let pct = max(0, min(1, boss.hp / max(1, boss.maxHP)))
            bossBarFill.xScale = pct
            bossBarFill.isHidden = false
            bossBarBG.isHidden = false
            bossLabel.isHidden = false
        } else {
            bossBarFill.isHidden = true
            bossBarBG.isHidden = true
            bossLabel.isHidden = true
        }
    }
}

