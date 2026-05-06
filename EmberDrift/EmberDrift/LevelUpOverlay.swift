import SpriteKit

final class LevelUpOverlay: SKNode {
    struct Choice {
        let id: String
        let title: String
        let subtitle: String
    }

    private let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.7), size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var cardNodes: [SKNode] = []
    private var choices: [Choice] = []

    func present(in parent: SKNode, sceneSize: CGSize, choices: [Choice]) {
        removeFromParent()
        removeAllChildren()
        cardNodes.removeAll(keepingCapacity: true)
        self.choices = choices

        dim.size = sceneSize
        dim.position = .zero
        dim.zPosition = 5000
        addChild(dim)

        titleLabel.text = "LEVEL UP"
        titleLabel.fontSize = 28
        titleLabel.position = CGPoint(x: 0, y: sceneSize.height * 0.25)
        titleLabel.zPosition = 5001
        addChild(titleLabel)

        let cardW = sceneSize.width * 0.72
        let cardH: CGFloat = 82
        let startY: CGFloat = 70
        let spacing: CGFloat = 16

        for (idx, c) in choices.enumerated() {
            let y = startY - CGFloat(idx) * (cardH + spacing)
            let card = makeCard(size: CGSize(width: cardW, height: cardH), title: c.title, subtitle: c.subtitle)
            card.name = "pick_\(c.id)"
            card.position = CGPoint(x: 0, y: y)
            card.zPosition = 5002
            addChild(card)
            cardNodes.append(card)
        }

        parent.addChild(self)
    }

    func pick(at locationInOverlaySpace: CGPoint) -> Choice? {
        let hits = nodes(at: locationInOverlaySpace)
        guard let name = hits.first(where: { ($0.name ?? "").hasPrefix("pick_") })?.name else { return nil }
        let id = String(name.dropFirst("pick_".count))
        return choices.first(where: { $0.id == id })
    }

    private func makeCard(size: CGSize, title: String, subtitle: String) -> SKNode {
        let node = SKNode()

        let bg = SKShapeNode(rectOf: size, cornerRadius: 14)
        bg.fillColor = SKColor(white: 0.12, alpha: 1)
        bg.strokeColor = SKColor(white: 1, alpha: 0.12)
        bg.lineWidth = 2
        node.addChild(bg)

        let t = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        t.text = title
        t.fontSize = 18
        t.horizontalAlignmentMode = .left
        t.verticalAlignmentMode = .center
        t.position = CGPoint(x: -size.width * 0.5 + 16, y: 12)
        node.addChild(t)

        let s = SKLabelNode(fontNamed: "AvenirNext-Regular")
        s.text = subtitle
        s.fontSize = 13
        s.alpha = 0.85
        s.horizontalAlignmentMode = .left
        s.verticalAlignmentMode = .center
        s.position = CGPoint(x: -size.width * 0.5 + 16, y: -16)
        node.addChild(s)

        return node
    }
}

