import SpriteKit
import UIKit

final class HUDOverlay {
    enum NodeName {
        static let pause = "hud_pause"
        static let debugWin = "debug_win"
        static let debugDie = "debug_die"
        static let debugLevelUp = "debug_lvl"
        static let debugMaxBuild = "debug_max"
    }

    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statsLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let xpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let timerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let bossLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let bossBarBG = SKShapeNode(rectOf: CGSize(width: 220, height: 12), cornerRadius: 6)
    private let bossBarFill = SKShapeNode(rectOf: CGSize(width: 216, height: 8), cornerRadius: 4)

    private let pauseLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let debugWinLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let debugDieLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let debugLevelUpLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let debugMaxBuildLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

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

        bossLabel.text = "ANDROID OVERLORD"
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

        pauseLabel.text = "PAUSE"
        pauseLabel.fontSize = 14
        pauseLabel.alpha = 0.9
        pauseLabel.name = NodeName.pause
        pauseLabel.horizontalAlignmentMode = .right
        pauseLabel.verticalAlignmentMode = .top
        pauseLabel.zPosition = 10_000
        cameraNode.addChild(pauseLabel)

        #if DEBUG
        for label in [debugWinLabel, debugDieLabel, debugLevelUpLabel, debugMaxBuildLabel] {
            label.fontSize = 12
            label.alpha = 0.85
            label.fontColor = .white
            label.horizontalAlignmentMode = .right
            label.verticalAlignmentMode = .top
            label.zPosition = 10_000
            cameraNode.addChild(label)
        }
        debugWinLabel.text = "WIN"
        debugWinLabel.name = NodeName.debugWin
        debugDieLabel.text = "DIE"
        debugDieLabel.name = NodeName.debugDie
        debugLevelUpLabel.text = "+LVL"
        debugLevelUpLabel.name = NodeName.debugLevelUp
        debugMaxBuildLabel.text = "MAX"
        debugMaxBuildLabel.name = NodeName.debugMaxBuild
        #endif
    }

    func layout(sceneSize: CGSize, safeAreaInsets: UIEdgeInsets = .zero) {
        let halfW = sceneSize.width * 0.5
        let halfH = sceneSize.height * 0.5
        let s = safeAreaInsets
        let marginTop = 16 + s.top
        let marginLeft = 16 + s.left
        let marginRight = 16 + s.right

        let topY = halfH - marginTop

        hpLabel.position = CGPoint(x: -halfW + marginLeft, y: topY)
        statsLabel.position = CGPoint(x: -halfW + marginLeft, y: topY - 24)
        xpLabel.position = CGPoint(x: -halfW + marginLeft, y: topY - 48)
        timerLabel.position = CGPoint(x: halfW - marginRight, y: topY)

        bossLabel.position = CGPoint(x: 0, y: topY - 4)
        bossBarBG.position = CGPoint(x: 0, y: topY - 24)
        bossBarFill.position = bossBarBG.position

        pauseLabel.position = CGPoint(x: halfW - marginRight, y: topY - 24)

        #if DEBUG
        debugWinLabel.position = CGPoint(x: halfW - marginRight, y: topY - 48)
        debugDieLabel.position = CGPoint(x: halfW - marginRight, y: topY - 68)
        debugLevelUpLabel.position = CGPoint(x: halfW - marginRight, y: topY - 88)
        debugMaxBuildLabel.position = CGPoint(x: halfW - marginRight, y: topY - 108)
        #endif
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

