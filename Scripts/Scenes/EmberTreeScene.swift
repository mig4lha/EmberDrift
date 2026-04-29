import SpriteKit

final class EmberTreeScene: SKScene {
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let backLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let ashLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private var rowLabels: [SKLabelNode] = []

    override func didMove(to view: SKView) {
        backgroundColor = .black

        titleLabel.text = "EMBER TREE"
        titleLabel.fontSize = 34
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.86)
        addChild(titleLabel)

        backLabel.text = "Back"
        backLabel.fontSize = 22
        backLabel.name = "back"
        backLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.10)
        addChild(backLabel)

        ashLabel.fontSize = 16
        ashLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.80)
        addChild(ashLabel)

        refresh()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.86)
        backLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.10)
        ashLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.80)
        layoutRows()
    }

    private func refresh() {
        let save = SaveStore.shared.load()
        ashLabel.text = "Ash: \(save.ash)"
        rebuildRows(save: save)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        if nodes.contains(where: { $0.name == "back" }) {
            let scene = MainMenuScene(size: size)
            scene.scaleMode = .resizeFill
            view?.presentScene(scene, transition: .push(with: .right, duration: 0.25))
            return
        }

        if let row = nodes.compactMap({ $0 as? SKLabelNode }).first(where: { ($0.name ?? "").hasPrefix("buy_") }) {
            handleBuy(named: row.name ?? "")
        }
    }

    private func rebuildRows(save: SaveData) {
        rowLabels.forEach { $0.removeFromParent() }
        rowLabels = []

        func addRow(_ name: String, _ text: String) {
            let label = SKLabelNode(fontNamed: "AvenirNext-Regular")
            label.fontSize = 15
            label.horizontalAlignmentMode = .left
            label.name = name
            label.text = text
            addChild(label)
            rowLabels.append(label)
        }

        addRow("header_stats", "Stat upgrades")
        addRow("buy_temperedBody", rowText(title: "Tempered body (+10 HP)", current: save.emberTree.temperedBody, cap: 5, cost: cost(base: 20, tier: save.emberTree.temperedBody)))
        addRow("buy_hotterCore", rowText(title: "Hotter core (+8% dmg)", current: save.emberTree.hotterCore, cap: 4, cost: cost(base: 30, tier: save.emberTree.hotterCore)))
        addRow("buy_swiftDrift", rowText(title: "Swift drift (+5% move)", current: save.emberTree.swiftDrift, cap: 3, cost: cost(base: 25, tier: save.emberTree.swiftDrift)))
        addRow("buy_emberHoard", rowText(title: "Ember hoard (+10% Ash)", current: save.emberTree.emberHoard, cap: 5, cost: cost(base: 30, tier: save.emberTree.emberHoard)))
        addRow("buy_stoked", rowText(title: "Stoked (+6% atk spd)", current: save.emberTree.stoked, cap: 3, cost: cost(base: 35, tier: save.emberTree.stoked)))

        addRow("header_unlocks", "Unlocks")
        addRow("buy_secondWind", unlockText(title: "Second wind (Rekindle appears)", owned: save.emberTree.secondWind, cost: 120))
        addRow("buy_volatileStart", unlockText(title: "Volatile start (random offense)", owned: save.emberTree.volatileStart, cost: 140))
        addRow("buy_kindlingCache", unlockText(title: "Kindling cache (+10% XP)", owned: save.emberTree.kindlingCache, cost: 120))
        addRow("buy_twinOffering", unlockText(title: "Twin offering (always 3 cards)", owned: save.emberTree.twinOffering, cost: 100))
        addRow("buy_ashenEcho", unlockText(title: "Ashen echo (bonus wave later)", owned: save.emberTree.ashenEcho, cost: 180))

        layoutRows()
    }

    private func layoutRows() {
        let startX = -size.width * 0.5 + 18
        var y = size.height * 0.72
        let line: CGFloat = 24
        for label in rowLabels {
            label.position = CGPoint(x: startX, y: y)
            label.fontColor = (label.name ?? "").hasPrefix("buy_") ? .white : .lightGray
            label.fontSize = (label.name ?? "").hasPrefix("header_") ? 17 : 15
            y -= line
        }
    }

    private func rowText(title: String, current: Int, cap: Int, cost: Int) -> String {
        if current >= cap { return "\(title): \(current)/\(cap) (MAX)" }
        return "\(title): \(current)/\(cap) — Cost \(cost)"
    }

    private func unlockText(title: String, owned: Bool, cost: Int) -> String {
        owned ? "\(title) — OWNED" : "\(title) — Cost \(cost)"
    }

    private func cost(base: Int, tier: Int) -> Int {
        base * (tier + 1)
    }

    private func handleBuy(named: String) {
        SaveStore.shared.update { save in
            switch named {
            case "buy_temperedBody":
                buyTier(&save.ash, &save.emberTree.temperedBody, cap: 5, cost: cost(base: 20, tier: save.emberTree.temperedBody))
            case "buy_hotterCore":
                buyTier(&save.ash, &save.emberTree.hotterCore, cap: 4, cost: cost(base: 30, tier: save.emberTree.hotterCore))
            case "buy_swiftDrift":
                buyTier(&save.ash, &save.emberTree.swiftDrift, cap: 3, cost: cost(base: 25, tier: save.emberTree.swiftDrift))
            case "buy_emberHoard":
                buyTier(&save.ash, &save.emberTree.emberHoard, cap: 5, cost: cost(base: 30, tier: save.emberTree.emberHoard))
            case "buy_stoked":
                buyTier(&save.ash, &save.emberTree.stoked, cap: 3, cost: cost(base: 35, tier: save.emberTree.stoked))

            case "buy_secondWind":
                buyUnlock(&save.ash, &save.emberTree.secondWind, cost: 120)
            case "buy_volatileStart":
                buyUnlock(&save.ash, &save.emberTree.volatileStart, cost: 140)
            case "buy_kindlingCache":
                buyUnlock(&save.ash, &save.emberTree.kindlingCache, cost: 120)
            case "buy_twinOffering":
                buyUnlock(&save.ash, &save.emberTree.twinOffering, cost: 100)
            case "buy_ashenEcho":
                buyUnlock(&save.ash, &save.emberTree.ashenEcho, cost: 180)
            default:
                break
            }
        }
        refresh()
    }

    private func buyTier(_ ash: inout Int, _ tier: inout Int, cap: Int, cost: Int) {
        guard tier < cap else { return }
        guard ash >= cost else { return }
        ash -= cost
        tier += 1
    }

    private func buyUnlock(_ ash: inout Int, _ owned: inout Bool, cost: Int) {
        guard !owned else { return }
        guard ash >= cost else { return }
        ash -= cost
        owned = true
    }
}

