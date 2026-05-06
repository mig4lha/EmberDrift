import SpriteKit

final class MainMenuScene: SKScene {
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let startLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")

    override func didMove(to view: SKView) {
        backgroundColor = .black

        titleLabel.text = "EMBER DRIFT"
        titleLabel.fontSize = 40
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        addChild(titleLabel)

        startLabel.text = "Start Run"
        startLabel.fontSize = 28
        startLabel.name = "start"
        startLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.50)
        addChild(startLabel)

        hintLabel.text = "Drag to move. Attack is automatic (next step)."
        hintLabel.fontSize = 14
        hintLabel.alpha = 0.8
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.30)
        addChild(hintLabel)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        startLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.50)
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.30)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touch = touches.first else { return }
        let location = touch.location(in: self)
        let hit = nodes(at: location)
        guard hit.contains(where: { $0.name == "start" }) else { return }

        let scene = RunScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.2))
    }
}

