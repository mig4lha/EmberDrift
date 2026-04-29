import SpriteKit

final class MainMenuScene: SKScene {
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let startLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let treeLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let statsLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")

    override func didMove(to view: SKView) {
        backgroundColor = .black

        titleLabel.text = "EMBER DRIFT"
        titleLabel.fontSize = 40
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        addChild(titleLabel)

        startLabel.text = "Start Run"
        startLabel.fontSize = 28
        startLabel.name = "start"
        startLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        addChild(startLabel)

        treeLabel.text = "Ember Tree"
        treeLabel.fontSize = 24
        treeLabel.name = "tree"
        treeLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.44)
        addChild(treeLabel)

        statsLabel.fontSize = 16
        statsLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        statsLabel.numberOfLines = 0
        statsLabel.preferredMaxLayoutWidth = size.width * 0.85
        addChild(statsLabel)

        refreshStats()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        startLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        treeLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.44)
        statsLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        statsLabel.preferredMaxLayoutWidth = size.width * 0.85
    }

    private func refreshStats() {
        let save = SaveStore.shared.load()
        let best = save.bestTimeSurvivedSeconds
        statsLabel.text = "Ash: \(save.ash)\nRuns: \(save.totalRuns)\nBest: \(best.formatAsMMSS())"
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        if nodes.contains(where: { $0.name == "start" }) {
            let scene = GameScene(size: size)
            scene.scaleMode = .resizeFill
            view?.presentScene(scene, transition: .fade(withDuration: 0.25))
        } else if nodes.contains(where: { $0.name == "tree" }) {
            let scene = EmberTreeScene(size: size)
            scene.scaleMode = .resizeFill
            view?.presentScene(scene, transition: .push(with: .left, duration: 0.25))
        }
    }
}
