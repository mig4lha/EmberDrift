import SpriteKit

final class LevelUpOverlay: SKNode {
    struct Choice {
        let kind: PowerUpKind
        let title: String
        let subtitle: String
    }

    private let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.75), size: .zero)
    private let header = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var cardNodes: [SKShapeNode] = []
    private var choices: [Choice] = []

    var onPick: ((PowerUpKind) -> Void)?

    override init() {
        super.init()
        isUserInteractionEnabled = false

        dim.zPosition = 1000
        addChild(dim)

        header.text = "LEVEL UP"
        header.fontSize = 26
        header.zPosition = 1001
        addChild(header)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(in camera: SKCameraNode, sceneSize: CGSize, choices: [Choice]) {
        removeFromParent()
        self.choices = choices
        cardNodes.forEach { $0.removeFromParent() }
        cardNodes = []

        dim.size = sceneSize
        dim.position = .zero

        header.position = CGPoint(x: 0, y: sceneSize.height * 0.25)

        let cardW = min(260, sceneSize.width * 0.75)
        let cardH: CGFloat = 78
        let spacing: CGFloat = 16
        let totalH = CGFloat(choices.count) * cardH + CGFloat(max(0, choices.count - 1)) * spacing
        var y = totalH * 0.5 - cardH * 0.5

        for (idx, choice) in choices.enumerated() {
            let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 14)
            card.fillColor = .darkGray
            card.strokeColor = .clear
            card.zPosition = 1001
            card.position = CGPoint(x: 0, y: y)
            card.name = "card_\(idx)"

            let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            title.text = choice.title
            title.fontSize = 18
            title.horizontalAlignmentMode = .left
            title.position = CGPoint(x: -cardW * 0.5 + 16, y: 10)
            title.zPosition = 1002
            card.addChild(title)

            let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
            subtitle.text = choice.subtitle
            subtitle.fontSize = 14
            subtitle.fontColor = .lightGray
            subtitle.horizontalAlignmentMode = .left
            subtitle.position = CGPoint(x: -cardW * 0.5 + 16, y: -16)
            subtitle.zPosition = 1002
            card.addChild(subtitle)

            addChild(card)
            cardNodes.append(card)

            y -= (cardH + spacing)
        }

        camera.addChild(self)
    }

    func hitTestPick(at locationInCamera: CGPoint) -> PowerUpKind? {
        let hits = nodes(at: locationInCamera)
        if let card = hits.first(where: { ($0.name ?? "").hasPrefix("card_") }) {
            guard let name = card.name, let idx = Int(name.replacingOccurrences(of: "card_", with: "")) else { return nil }
            guard idx >= 0, idx < choices.count else { return nil }
            return choices[idx].kind
        }
        return nil
    }
}

