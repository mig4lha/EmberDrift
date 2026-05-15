import SpriteKit
import UIKit

final class LevelUpOverlay: SKNode {
    struct Choice {
        let id: String
        let title: String
        let subtitle: String
    }

    private let confirmHoldDuration: TimeInterval = 0.5

    private let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.7), size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")

    private var cardNodes: [SKNode] = []
    private var choices: [Choice] = []
    private var cardSize: CGSize = .zero

    private var holdChoiceId: String?
    private var holdElapsed: TimeInterval = 0
    private var holdProgressFill: SKShapeNode?

    func present(in parent: SKNode, sceneSize: CGSize, safeAreaInsets: UIEdgeInsets = .zero, choices: [Choice]) {
        removeFromParent()
        removeAllChildren()
        cardNodes.removeAll(keepingCapacity: true)
        self.choices = choices
        cancelHold()

        dim.size = sceneSize
        dim.position = .zero
        dim.zPosition = 5000
        addChild(dim)

        let topNudge = safeAreaInsets.top

        titleLabel.text = "LEVEL UP"
        titleLabel.fontSize = 28
        titleLabel.position = CGPoint(x: 0, y: sceneSize.height * 0.25 - topNudge)
        titleLabel.zPosition = 5001
        addChild(titleLabel)

        hintLabel.text = "Hold a card for 0.5s to confirm"
        hintLabel.fontSize = 14
        hintLabel.alpha = 0.75
        hintLabel.position = CGPoint(x: 0, y: -sceneSize.height * 0.32)
        hintLabel.zPosition = 5001
        addChild(hintLabel)

        cardSize = CGSize(width: sceneSize.width * 0.72, height: 82)
        let startY: CGFloat = 70
        let spacing: CGFloat = 16

        for (idx, c) in choices.enumerated() {
            let y = startY - CGFloat(idx) * (cardSize.height + spacing)
            let card = makeCard(size: cardSize, title: c.title, subtitle: c.subtitle)
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

    /// Start hold on a card under the finger.
    @discardableResult
    func beginHold(at locationInOverlaySpace: CGPoint) -> Bool {
        cancelHold()
        guard let choice = pick(at: locationInOverlaySpace) else { return false }
        holdChoiceId = choice.id
        holdElapsed = 0
        setCardHighlighted(choice.id, highlighted: true)
        updateHoldProgress(0)
        return true
    }

    /// Returns a confirmed choice when hold duration is met; nil while waiting or if finger left the card.
    func advanceHold(at locationInOverlaySpace: CGPoint, dt: TimeInterval) -> Choice? {
        guard dt > 0, let id = holdChoiceId else { return nil }
        guard pick(at: locationInOverlaySpace)?.id == id else {
            cancelHold()
            return nil
        }

        holdElapsed += dt
        let progress = min(1, holdElapsed / confirmHoldDuration)
        updateHoldProgress(progress)

        guard holdElapsed >= confirmHoldDuration else { return nil }
        let choice = choices.first(where: { $0.id == id })
        cancelHold()
        return choice
    }

    func cancelHold() {
        if let id = holdChoiceId {
            setCardHighlighted(id, highlighted: false)
        }
        holdChoiceId = nil
        holdElapsed = 0
        holdProgressFill?.removeFromParent()
        holdProgressFill = nil
    }

    var isHolding: Bool { holdChoiceId != nil }

    func isFingerOnHeldCard(at locationInOverlaySpace: CGPoint) -> Bool {
        guard let id = holdChoiceId else { return false }
        return pick(at: locationInOverlaySpace)?.id == id
    }

    // MARK: - Card UI

    private func makeCard(size: CGSize, title: String, subtitle: String) -> SKNode {
        let node = SKNode()

        let bg = SKShapeNode(rectOf: size, cornerRadius: 14)
        bg.name = "card_bg"
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
        t.zPosition = 1
        node.addChild(t)

        let s = SKLabelNode(fontNamed: "AvenirNext-Regular")
        s.text = subtitle
        s.fontSize = 13
        s.alpha = 0.85
        s.horizontalAlignmentMode = .left
        s.verticalAlignmentMode = .center
        s.position = CGPoint(x: -size.width * 0.5 + 16, y: -16)
        s.zPosition = 1
        node.addChild(s)

        return node
    }

    private func cardNode(for id: String) -> SKNode? {
        cardNodes.first(where: { $0.name == "pick_\(id)" })
    }

    private func setCardHighlighted(_ id: String, highlighted: Bool) {
        guard let card = cardNode(for: id),
              let bg = card.childNode(withName: "card_bg") as? SKShapeNode else { return }
        if highlighted {
            bg.strokeColor = SKColor(red: 1, green: 0.55, blue: 0.2, alpha: 0.95)
            bg.lineWidth = 3
            bg.fillColor = SKColor(white: 0.18, alpha: 1)
        } else {
            bg.strokeColor = SKColor(white: 1, alpha: 0.12)
            bg.lineWidth = 2
            bg.fillColor = SKColor(white: 0.12, alpha: 1)
        }
    }

    private func updateHoldProgress(_ progress: CGFloat) {
        guard let id = holdChoiceId, let card = cardNode(for: id) else { return }

        holdProgressFill?.removeFromParent()

        let barH: CGFloat = 5
        let inset: CGFloat = 10
        let maxW = cardSize.width - inset * 2
        let w = max(4, maxW * progress)
        let rect = CGRect(x: -cardSize.width * 0.5 + inset, y: -cardSize.height * 0.5 + 8, width: w, height: barH)
        let fill = SKShapeNode(rect: rect, cornerRadius: 2)
        fill.fillColor = SKColor(red: 1, green: 0.5, blue: 0.15, alpha: 0.95)
        fill.strokeColor = .clear
        fill.zPosition = 2
        card.addChild(fill)
        holdProgressFill = fill
    }
}
