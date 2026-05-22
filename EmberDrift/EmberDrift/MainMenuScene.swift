import SpriteKit

final class MainMenuScene: SKScene {
    private enum NodeName {
        static let start = "start"
    }

    private var backgroundNode: SKNode?
    private let logoSprite = SKSpriteNode()
    private let startButton = SKSpriteNode()
    private let hintPanel = SKSpriteNode()
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let marketSharePanel = SKSpriteNode()
    private let marketShareLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    override func didMove(to view: SKView) {
        backgroundColor = .black
        backgroundNode = GameAssets.installBackground(in: self, named: GameAssets.ImageName.bgMenu, scrimAlpha: 0.38)

        logoSprite.zPosition = MenuUI.Z.button
        startButton.name = NodeName.start
        startButton.zPosition = MenuUI.Z.button
        hintPanel.zPosition = MenuUI.Z.panel
        marketSharePanel.zPosition = MenuUI.Z.panel

        addChild(logoSprite)
        addChild(startButton)
        addChild(hintPanel)
        addChild(hintLabel)
        addChild(marketSharePanel)
        addChild(marketShareLabel)

        refreshMarketShareText()
        layoutUI()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        backgroundNode?.removeFromParent()
        backgroundNode = GameAssets.installBackground(in: self, named: GameAssets.ImageName.bgMenu, scrimAlpha: 0.38)
        layoutUI()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touch = touches.first else { return }
        let location = touch.location(in: self)
        let hit = nodes(at: location)
        guard hit.contains(where: { $0.name == NodeName.start }) else { return }

        let scene = RunScene(size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: .fade(withDuration: 0.2))
    }

    private func refreshMarketShareText() {
        marketShareLabel.text = "Market Share: \(SaveStore.shared.ash)"
    }

    private func layoutUI() {
        let w = size.width
        let h = size.height

        if let tex = GameAssets.texture(GameAssets.ImageName.uiLogoAppleAttack) {
            logoSprite.texture = tex
            let targetW = w * 0.84
            let aspect = tex.size().height / max(tex.size().width, 1)
            logoSprite.size = CGSize(width: targetW, height: targetW * aspect)
            logoSprite.isHidden = false
        } else {
            logoSprite.isHidden = true
        }
        logoSprite.position = CGPoint(x: w * 0.5, y: h * 0.72)

        _ = MenuUI.applyButton(startButton, width: w * 0.68)
        startButton.position = CGPoint(x: w * 0.5, y: h * 0.50)

        hintLabel.text = "Drag to move. Your attacks fire automatically."
        MenuUI.styleContentLabel(hintLabel, fontSize: 13, maxWidth: w * 0.72)
        hintLabel.fontName = "AvenirNext-Regular"
        hintLabel.alpha = 0.95
        _ = MenuUI.applyPanel(hintPanel, width: w * 0.78, heightScale: 0.55)
        hintPanel.position = CGPoint(x: w * 0.5, y: h * 0.30)
        hintLabel.position = hintPanel.position

        refreshMarketShareText()
        MenuUI.styleContentLabel(marketShareLabel, fontSize: 17)
        _ = MenuUI.applyPanel(marketSharePanel, width: w * 0.62, heightScale: 0.42)
        marketSharePanel.position = CGPoint(x: w * 0.5, y: h * 0.20)
        marketShareLabel.position = marketSharePanel.position
    }
}
