import SpriteKit

struct RunStats {
    let timeSurvivedSeconds: Int
    let kills: Int
    let killsScuttler: Int
    let killsBrute: Int
    let finalLevel: Int
    let ashEarned: Int
    let bossKilled: Bool
    let powerUpCounts: [String: Int]
}

final class RunSummaryScene: SKScene {
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let bodyLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let againLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let menuLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    private let stats: RunStats

    init(size: CGSize, stats: RunStats) {
        self.stats = stats
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = .black

        titleLabel.text = stats.bossKilled ? "VICTORY" : "GAME OVER"
        titleLabel.fontSize = 40
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        addChild(titleLabel)

        bodyLabel.fontSize = 16
        bodyLabel.numberOfLines = 0
        bodyLabel.preferredMaxLayoutWidth = size.width * 0.9
        bodyLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        addChild(bodyLabel)

        againLabel.text = "Run Again"
        againLabel.fontSize = 24
        againLabel.name = "again"
        againLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        addChild(againLabel)

        menuLabel.text = "Main Menu"
        menuLabel.fontSize = 20
        menuLabel.name = "menu"
        menuLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
        addChild(menuLabel)

        applySaveSideEffects()
        refreshBody()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        bodyLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        bodyLabel.preferredMaxLayoutWidth = size.width * 0.9
        againLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        menuLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
    }

    private func refreshBody() {
        let powerups: String = {
            guard !stats.powerUpCounts.isEmpty else { return "—" }
            let items = stats.powerUpCounts
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key.capitalized): \($0.value)" }
            return items.joined(separator: ", ")
        }()
        bodyLabel.text = """
Time: \(formatMMSS(stats.timeSurvivedSeconds))
Kills: \(stats.kills) (Scuttlers \(stats.killsScuttler), Brutes \(stats.killsBrute))
Level: \(stats.finalLevel)
Ash earned: \(stats.ashEarned)
Power-ups: \(powerups)
"""
    }

    private func applySaveSideEffects() {
        SaveStore.shared.ash += stats.ashEarned
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let t = touches.first else { return }
        let location = t.location(in: self)
        let hit = nodes(at: location)
        if hit.contains(where: { $0.name == "again" }) {
            let scene = RunScene(size: size)
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: .fade(withDuration: 0.25))
        } else if hit.contains(where: { $0.name == "menu" }) {
            let scene = MainMenuScene(size: size)
            scene.scaleMode = .resizeFill
            view.presentScene(scene, transition: .fade(withDuration: 0.25))
        }
    }

    private func formatMMSS(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

