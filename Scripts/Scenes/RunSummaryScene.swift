import SpriteKit

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

        titleLabel.text = "RUN SUMMARY"
        titleLabel.fontSize = 32
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
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        bodyLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        bodyLabel.preferredMaxLayoutWidth = size.width * 0.9
        againLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        menuLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
    }

    private func refreshBody() {
        let scuttlers = stats.enemiesKilledByType[.scuttler] ?? 0
        let brutes = stats.enemiesKilledByType[.brute] ?? 0
        let total = scuttlers + brutes
        let powerUps = stats.powerUpsTaken.map { $0.rawValue }.joined(separator: ", ")

        bodyLabel.text = """
Time: \(stats.timeSurvivedSeconds.formatAsMMSS())
Kills: \(total) (Scuttlers \(scuttlers), Brutes \(brutes))
Level: \(stats.finalLevel)
Ash: \(stats.ashEarned)
Build: \(powerUps.isEmpty ? "—" : powerUps)
"""
    }

    private func applySaveSideEffects() {
        SaveStore.shared.update { save in
            save.totalRuns += 1
            if stats.timeSurvivedSeconds > save.bestTimeSurvivedSeconds {
                save.bestTimeSurvivedSeconds = stats.timeSurvivedSeconds
            }
            save.ash += stats.ashEarned
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let location = t.location(in: self)
        let hit = nodes(at: location)
        if hit.contains(where: { $0.name == "again" }) {
            let scene = GameScene(size: size)
            scene.scaleMode = .resizeFill
            view?.presentScene(scene, transition: .fade(withDuration: 0.25))
        } else if hit.contains(where: { $0.name == "menu" }) {
            let scene = MainMenuScene(size: size)
            scene.scaleMode = .resizeFill
            view?.presentScene(scene, transition: .fade(withDuration: 0.25))
        }
    }
}

