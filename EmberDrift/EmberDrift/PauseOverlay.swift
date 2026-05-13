import SpriteKit
import UIKit

final class PauseOverlay: SKNode {
    enum Action {
        case resume
        case mainMenu
    }

    private let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.75), size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let resumeLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let menuLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let powerupsTitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let powerupsBody = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let powerupsCrop = SKCropNode()
    private let powerupsMask = SKSpriteNode(color: .white, size: .zero)

    func present(in parent: SKNode, sceneSize: CGSize, safeAreaInsets: UIEdgeInsets = .zero, powerupsTaken: [String]) {
        removeFromParent()
        removeAllChildren()
        powerupsCrop.removeAllChildren()
        powerupsBody.removeFromParent()

        dim.size = sceneSize
        dim.position = .zero
        dim.zPosition = 6000
        addChild(dim)

        let topNudge = safeAreaInsets.top

        titleLabel.text = "PAUSED"
        titleLabel.fontSize = 32
        titleLabel.position = CGPoint(x: 0, y: sceneSize.height * 0.25 - topNudge)
        titleLabel.zPosition = 6001
        addChild(titleLabel)

        resumeLabel.text = "Resume"
        resumeLabel.fontSize = 24
        resumeLabel.name = "pause_resume"
        resumeLabel.position = CGPoint(x: 0, y: sceneSize.height * 0.10)
        resumeLabel.zPosition = 6002
        addChild(resumeLabel)

        menuLabel.text = "Main Menu"
        menuLabel.fontSize = 20
        menuLabel.name = "pause_menu"
        menuLabel.position = CGPoint(x: 0, y: sceneSize.height * 0.10 - 38)
        menuLabel.zPosition = 6002
        addChild(menuLabel)

        powerupsTitle.text = "Power-ups"
        powerupsTitle.fontSize = 16
        powerupsTitle.alpha = 0.9
        powerupsTitle.position = CGPoint(x: 0, y: menuLabel.position.y - 56)
        powerupsTitle.zPosition = 6001
        addChild(powerupsTitle)

        powerupsBody.fontSize = 14
        powerupsBody.alpha = 0.85
        powerupsBody.numberOfLines = 0
        powerupsBody.preferredMaxLayoutWidth = sceneSize.width * 0.8
        powerupsBody.horizontalAlignmentMode = .center
        powerupsBody.verticalAlignmentMode = .top
        let panelWidth = sceneSize.width * 0.86
        let panelTopY = powerupsTitle.position.y - 18
        let panelBottomY = -sceneSize.height * 0.30
        let panelHeight = max(90, panelTopY - panelBottomY)

        let approxLineHeight = powerupsBody.fontSize * 1.25
        let maxLines = max(3, Int(panelHeight / approxLineHeight))

        let lines: [String]
        if powerupsTaken.isEmpty {
            lines = ["—"]
        } else if powerupsTaken.count <= maxLines {
            lines = powerupsTaken
        } else {
            let remaining = powerupsTaken.count - maxLines + 1
            lines = Array(powerupsTaken.prefix(maxLines - 1)) + ["… +\(remaining) more"]
        }

        powerupsBody.text = lines.joined(separator: "\n")
        powerupsBody.zPosition = 6001

        // Crop panel is positioned at its center; contents use local coordinates.
        let panelCenterY = panelTopY - panelHeight * 0.5
        powerupsCrop.position = CGPoint(x: 0, y: panelCenterY)
        powerupsCrop.zPosition = 6001

        powerupsMask.size = CGSize(width: panelWidth, height: panelHeight)
        powerupsMask.position = .zero
        powerupsCrop.maskNode = powerupsMask

        // Anchor the label to the TOP of the panel, so it grows downward.
        powerupsBody.position = CGPoint(x: 0, y: panelHeight * 0.5 - 2)

        addChild(powerupsCrop)
        if powerupsBody.parent == nil {
            powerupsCrop.addChild(powerupsBody)
        }

        parent.addChild(self)
    }

    func action(at locationInOverlaySpace: CGPoint) -> Action? {
        let hits = nodes(at: locationInOverlaySpace)
        if hits.contains(where: { $0.name == "pause_resume" }) { return .resume }
        if hits.contains(where: { $0.name == "pause_menu" }) { return .mainMenu }
        return nil
    }
}

