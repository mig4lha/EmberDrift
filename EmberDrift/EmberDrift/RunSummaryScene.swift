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
    private enum NodeName {
        static let reboot = "reboot"
        static let menu = "menu"
        static let upgradesCrop = "upgrades_crop"
    }

    private enum Layout {
        static let topMargin: CGFloat = 52
        static let titleFontSize: CGFloat = 22
        static let statFontSize: CGFloat = 13
        static let upgradeFontSize: CGFloat = 12
        static let lineGap: CGFloat = 6
        static let sectionPad: CGFloat = 10
        static let panelPad: CGFloat = 14
        static let buttonGap: CGFloat = 2
        static let buttonWidthRatio: CGFloat = 0.46
        static let panelWidthRatio: CGFloat = 0.88
        static let panelHeightGrowth: CGFloat = 1.1
        static let titlePanelGap: CGFloat = 14
        static let panelButtonGap: CGFloat = 10
        static let buttonDrop: CGFloat = 22
    }

    private var backgroundNode: SKNode?
    private let titleNode = SKNode()
    private let panelContainer = SKNode()
    private let panelBackdrop = SKShapeNode()
    private let fixedStatsNode = SKNode()
    private let upgradesHeaderNode = SKNode()
    private let upgradesCrop = SKCropNode()
    private let upgradesMask = SKSpriteNode(color: .white, size: .zero)
    private let upgradesScrollNode = SKNode()
    private let rebootButton = SKSpriteNode()
    private let menuButton = SKSpriteNode()

    private var panelSize: CGSize = .zero
    private var upgradesCropHeight: CGFloat = 0
    private var upgradesContentHeight: CGFloat = 0
    private var upgradesScrollOffset: CGFloat = 0
    private var upgradesLineHeight: CGFloat = 0
    private var upgradesDragStartY: CGFloat = 0
    private var upgradesScrollStartOffset: CGFloat = 0
    private var isDraggingUpgrades = false
    private var didDragUpgrades = false

    private let stats: RunStats

    init(size: CGSize, stats: RunStats) {
        self.stats = stats
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        installBackground()

        titleNode.zPosition = MenuUI.Z.content
        panelContainer.zPosition = MenuUI.Z.content
        rebootButton.name = NodeName.reboot
        rebootButton.zPosition = MenuUI.Z.button
        menuButton.name = NodeName.menu
        menuButton.zPosition = MenuUI.Z.button

        upgradesCrop.name = NodeName.upgradesCrop
        upgradesCrop.maskNode = upgradesMask
        panelContainer.isUserInteractionEnabled = false
        upgradesCrop.isUserInteractionEnabled = false

        addChild(titleNode)
        addChild(panelContainer)
        panelContainer.addChild(panelBackdrop)
        panelContainer.addChild(fixedStatsNode)
        panelContainer.addChild(upgradesHeaderNode)
        panelContainer.addChild(upgradesCrop)
        upgradesCrop.addChild(upgradesScrollNode)
        addChild(rebootButton)
        addChild(menuButton)

        applySaveSideEffects()
        layoutUI()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        installBackground()
        layoutUI()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        didDragUpgrades = false
        isDraggingUpgrades = false

        let loc = touch.location(in: self)
        if buttonContains(loc, rebootButton) || buttonContains(loc, menuButton) {
            return
        }

        if upgradesCropContains(loc), upgradesContentHeight > upgradesCropHeight {
            isDraggingUpgrades = true
            upgradesDragStartY = loc.y
            upgradesScrollStartOffset = upgradesScrollOffset
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDraggingUpgrades, let touch = touches.first else { return }
        let dy = touch.location(in: self).y - upgradesDragStartY
        if abs(dy) > 4 { didDragUpgrades = true }
        setUpgradesScroll(upgradesScrollStartOffset + dy)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            isDraggingUpgrades = false
            didDragUpgrades = false
        }
        guard let view, let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if !didDragUpgrades {
            if buttonContains(loc, rebootButton) {
                let scene = RunScene(size: size)
                scene.scaleMode = .resizeFill
                view.presentScene(scene, transition: .fade(withDuration: 0.25))
                return
            }
            if buttonContains(loc, menuButton) {
                let scene = MainMenuScene(size: size)
                scene.scaleMode = .resizeFill
                view.presentScene(scene, transition: .fade(withDuration: 0.25))
                return
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingUpgrades = false
        didDragUpgrades = false
    }

    private func installBackground() {
        let bgName = stats.bossKilled ? GameAssets.ImageName.bgVictory : GameAssets.ImageName.bgDefeat
        backgroundNode?.removeFromParent()
        backgroundNode = GameAssets.installBackground(in: self, named: bgName, scrimAlpha: 0.22)
    }

    private func fixedStatLines() -> [String] {
        [
            "Time: \(formatMMSS(stats.timeSurvivedSeconds))",
            "Kills: \(stats.kills)  (Windows \(stats.killsScuttler), Linux \(stats.killsBrute))",
            "Level: \(stats.finalLevel)",
            "Market Share: +\(stats.ashEarned)",
        ]
    }

    private func upgradeLines() -> [String] {
        guard !stats.powerUpCounts.isEmpty else { return ["—"] }
        return stats.powerUpCounts
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key): \($0.value)" }
    }

    private func layoutUI() {
        let w = size.width
        let h = size.height
        let panelW = w * Layout.panelWidthRatio
        let buttonW = w * Layout.buttonWidthRatio

        _ = MenuUI.applyButton(menuButton, imageName: GameAssets.ImageName.uiBtnMainMenu, width: buttonW)
        _ = MenuUI.applyButton(rebootButton, imageName: GameAssets.ImageName.uiBtnReboot, width: buttonW)

        let menuH = menuButton.isHidden ? 36 : menuButton.size.height
        let rebootH = rebootButton.isHidden ? 36 : rebootButton.size.height

        titleNode.removeAllChildren()
        let titleText = stats.bossKilled ? "MONOPOLY SECURED" : "ECOSYSTEM LOST"
        let title = MenuUI.makeOutlinedLabel(
            text: titleText,
            fontSize: Layout.titleFontSize,
            bold: true,
            maxWidth: w * 0.9
        )
        titleNode.addChild(title)
        let titleH = title.calculateAccumulatedFrame().height
        titleNode.position = CGPoint(x: w * 0.5, y: h - Layout.topMargin - titleH * 0.5)

        // Panel top stays fixed under the title; height grows downward only.
        let panelTopY = titleNode.position.y - titleH * 0.5 - Layout.titlePanelGap

        let buttonStackH = menuH + Layout.buttonGap + rebootH
        let basePanelH = max(80, panelTopY - (h * 0.10 + buttonStackH + Layout.panelButtonGap))
        let panelH = basePanelH * Layout.panelHeightGrowth
        let panelCenterY = panelTopY - panelH * 0.5
        let panelBottomY = panelTopY - panelH

        rebootButton.position = CGPoint(
            x: w * 0.5,
            y: panelBottomY - Layout.panelButtonGap - rebootH * 0.5 - Layout.buttonDrop
        )
        menuButton.position = CGPoint(
            x: w * 0.5,
            y: rebootButton.position.y - rebootH * 0.5 - Layout.buttonGap - menuH * 0.5
        )

        panelSize = CGSize(width: panelW, height: panelH)
        panelContainer.position = CGPoint(x: w * 0.5, y: panelCenterY)

        panelBackdrop.path = CGPath(
            roundedRect: CGRect(x: -panelW * 0.5, y: -panelH * 0.5, width: panelW, height: panelH),
            cornerWidth: 12,
            cornerHeight: 12,
            transform: nil
        )
        panelBackdrop.fillColor = SKColor(white: 0.08, alpha: 0.52)
        panelBackdrop.strokeColor = SKColor(white: 1, alpha: 0.12)
        panelBackdrop.lineWidth = 1.5
        panelBackdrop.zPosition = -2

        layoutFixedStats(panelW: panelW, panelH: panelH)
        layoutUpgradesList(panelW: panelW, panelH: panelH)

    }

    private func layoutFixedStats(panelW: CGFloat, panelH: CGFloat) {
        fixedStatsNode.removeAllChildren()
        let lines = fixedStatLines()
        let lineSpacing = Layout.statFontSize + Layout.lineGap
        var y = panelH * 0.5 - Layout.panelPad

        for line in lines {
            let node = MenuUI.makeOutlinedLabel(
                text: line,
                fontSize: Layout.statFontSize,
                bold: true,
                maxWidth: panelW - 28
            )
            node.position = CGPoint(x: 0, y: y)
            fixedStatsNode.addChild(node)
            y -= lineSpacing
        }

        let statsBottom = y
        upgradesHeaderNode.removeAllChildren()
        let header = MenuUI.makeOutlinedLabel(
            text: "Upgrades",
            fontSize: Layout.statFontSize,
            bold: true
        )
        header.position = CGPoint(x: 0, y: statsBottom - Layout.sectionPad)
        upgradesHeaderNode.addChild(header)

        let headerBottom = statsBottom - Layout.sectionPad - (Layout.statFontSize + 4)
        let cropTop = headerBottom - 6
        let cropBottom = -panelH * 0.5 + Layout.panelPad
        upgradesCropHeight = max(48, cropTop - cropBottom)
    }

    private func layoutUpgradesList(panelW: CGFloat, panelH: CGFloat) {
        upgradesScrollNode.removeAllChildren()
        let lines = upgradeLines()
        upgradesLineHeight = Layout.upgradeFontSize + Layout.lineGap + 4
        let topInset: CGFloat = 4

        for (index, line) in lines.enumerated() {
            let node = MenuUI.makeOutlinedLabel(
                text: line,
                fontSize: Layout.upgradeFontSize,
                bold: false,
                maxWidth: panelW - 36
            )
            let centerY = -topInset - upgradesLineHeight * 0.5 - CGFloat(index) * upgradesLineHeight
            node.position = CGPoint(x: 0, y: centerY)
            upgradesScrollNode.addChild(node)
        }

        let lastCenterY = -topInset - upgradesLineHeight * 0.5 - CGFloat(max(0, lines.count - 1)) * upgradesLineHeight
        let contentTop: CGFloat = 0
        let contentBottom = lastCenterY - upgradesLineHeight * 0.5
        upgradesContentHeight = contentTop - contentBottom

        let cropW = panelW - 28
        upgradesMask.size = CGSize(width: cropW, height: upgradesCropHeight)

        let cropCenterY = (-panelH * 0.5 + Layout.panelPad) + upgradesCropHeight * 0.5
        upgradesCrop.position = CGPoint(x: 0, y: cropCenterY)

        let maxScroll = max(0, upgradesContentHeight - upgradesCropHeight)
        upgradesScrollOffset = min(upgradesScrollOffset, maxScroll)
        applyUpgradesScrollPosition()
    }

    private func setUpgradesScroll(_ offset: CGFloat) {
        let maxScroll = max(0, upgradesContentHeight - upgradesCropHeight)
        upgradesScrollOffset = min(maxScroll, max(0, offset))
        applyUpgradesScrollPosition()
    }

    private func applyUpgradesScrollPosition() {
        let cropTop = upgradesCropHeight * 0.5
        upgradesScrollNode.position = CGPoint(x: 0, y: cropTop - upgradesScrollOffset)
    }

    private func applySaveSideEffects() {
        SaveStore.shared.ash += stats.ashEarned
    }

    private func buttonContains(_ pointInScene: CGPoint, _ button: SKSpriteNode) -> Bool {
        guard !button.isHidden else { return false }
        return button.calculateAccumulatedFrame().contains(pointInScene)
    }

    private func upgradesCropContains(_ pointInScene: CGPoint) -> Bool {
        let local = panelContainer.convert(pointInScene, from: self)
        let halfW = (panelSize.width - 28) * 0.5
        let halfH = upgradesCropHeight * 0.5
        let center = upgradesCrop.position
        let rect = CGRect(
            x: center.x - halfW,
            y: center.y - halfH,
            width: halfW * 2,
            height: halfH * 2
        )
        return rect.contains(local)
    }

    private func formatMMSS(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
