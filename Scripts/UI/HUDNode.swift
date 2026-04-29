import SpriteKit

final class HUDNode: SKNode {
    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let xpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let timerLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let bossLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    override init() {
        super.init()

        hpLabel.fontSize = 16
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.position = CGPoint(x: 12, y: -12)
        addChild(hpLabel)

        xpLabel.fontSize = 14
        xpLabel.horizontalAlignmentMode = .left
        addChild(xpLabel)

        timerLabel.fontSize = 16
        timerLabel.horizontalAlignmentMode = .right
        timerLabel.position = CGPoint(x: -12, y: -12)
        addChild(timerLabel)

        bossLabel.fontSize = 14
        bossLabel.horizontalAlignmentMode = .center
        bossLabel.fontColor = .systemPink
        bossLabel.isHidden = true
        addChild(bossLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func layout(for size: CGSize) {
        hpLabel.position = CGPoint(x: -size.width * 0.5 + 12, y: size.height * 0.5 - 28)
        xpLabel.position = CGPoint(x: -size.width * 0.5 + 12, y: size.height * 0.5 - 48)
        timerLabel.position = CGPoint(x: size.width * 0.5 - 12, y: size.height * 0.5 - 28)
        bossLabel.position = CGPoint(x: 0, y: size.height * 0.5 - 28)
    }

    func update(hp: CGFloat, maxHP: CGFloat, xp: Int, xpNeeded: Int, level: Int, elapsedSeconds: Int, bossHP: CGFloat?, bossMaxHP: CGFloat?) {
        hpLabel.text = "HP \(Int(hp))/\(Int(maxHP))"
        xpLabel.text = "LV \(level)  XP \(xp)/\(xpNeeded)"
        timerLabel.text = elapsedSeconds.formatAsMMSS()

        if let bossHP, let bossMaxHP {
            bossLabel.isHidden = false
            bossLabel.text = "BOSS \(Int(bossHP))/\(Int(bossMaxHP))"
        } else {
            bossLabel.isHidden = true
            bossLabel.text = nil
        }
    }
}

