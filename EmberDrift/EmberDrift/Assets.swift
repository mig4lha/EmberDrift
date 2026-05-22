import SpriteKit

enum GameAssets {
    enum ImageName {
        static let playerCinder = "player_cinder"
        static let enemyScuttler = "enemy_scuttler"
        static let enemyBrute = "enemy_brute"
        static let bossVoidColossus = "boss_void_colossus"
        static let tileGround = "tile_ground"
        static let xpOrb = "xp_orb"
        static let bgMenu = "bg_menu"
        static let bgVictory = "bg_victory"
        static let bgDefeat = "bg_defeat"
        static let uiLogoAppleAttack = "ui_logo_apple_attack"
        static let uiBtnStartConquest = "ui_btn_start_conquest"
        static let uiBtnReboot = "ui_btn_reboot"
        static let uiBtnMainMenu = "ui_btn_main_menu"
        static let uiPanelInfoBadge = "ui_panel_info_badge"
    }

    /// Sprite sized to `targetWidth` while preserving texture aspect ratio.
    static func sprite(named imageName: String, targetWidth: CGFloat) -> SKSpriteNode? {
        guard let tex = texture(imageName) else { return nil }
        let node = SKSpriteNode(texture: tex)
        let aspect = tex.size().height / max(tex.size().width, 1)
        node.size = CGSize(width: targetWidth, height: targetWidth * aspect)
        return node
    }

    static func texture(_ name: String) -> SKTexture? {
        let texture = SKTexture(imageNamed: name)
        // If the asset doesn't exist, SpriteKit returns a 1x1 placeholder.
        // We treat a 1x1 as "missing" so we can fall back to shapes/colors.
        let size = texture.size()
        return (size.width <= 1.1 && size.height <= 1.1) ? nil : texture
    }

    /// Full-screen background with optional dark scrim for readable labels.
    @discardableResult
    static func installBackground(
        in scene: SKScene,
        named imageName: String,
        scrimAlpha: CGFloat = 0.42
    ) -> SKNode? {
        scene.childNode(withName: "//scene_background")?.removeFromParent()

        let container = SKNode()
        container.name = "scene_background"
        container.zPosition = -10_000

        if let tex = texture(imageName) {
            let sprite = SKSpriteNode(texture: tex)
            sprite.position = CGPoint(x: scene.size.width * 0.5, y: scene.size.height * 0.5)
            let scale = max(scene.size.width / tex.size().width, scene.size.height / tex.size().height)
            sprite.setScale(scale)
            container.addChild(sprite)
        } else {
            scene.backgroundColor = .black
            return nil
        }

        if scrimAlpha > 0 {
            let scrim = SKSpriteNode(color: SKColor(white: 0, alpha: scrimAlpha), size: scene.size)
            scrim.position = CGPoint(x: scene.size.width * 0.5, y: scene.size.height * 0.5)
            container.addChild(scrim)
        }

        scene.addChild(container)
        return container
    }
}

// MARK: - Shared menu / summary UI (panels + buttons)

enum MenuUI {
    enum Z {
        static let panel: CGFloat = 9
        static let button: CGFloat = 10
        static let content: CGFloat = 11
    }

    static func panelSize(for texture: SKTexture, width: CGFloat, heightScale: CGFloat) -> CGSize {
        let aspect = texture.size().height / max(texture.size().width, 1)
        return CGSize(width: width, height: max(44, width * aspect * heightScale))
    }

    static func buttonSize(for texture: SKTexture, width: CGFloat) -> CGSize {
        let aspect = texture.size().height / max(texture.size().width, 1)
        return CGSize(width: width, height: width * aspect)
    }

    @discardableResult
    static func applyPanel(_ sprite: SKSpriteNode, width: CGFloat, heightScale: CGFloat = 0.42) -> Bool {
        guard let tex = GameAssets.texture(GameAssets.ImageName.uiPanelInfoBadge) else {
            sprite.isHidden = true
            return false
        }
        sprite.texture = tex
        sprite.size = panelSize(for: tex, width: width, heightScale: heightScale)
        sprite.isHidden = false
        return true
    }

    @discardableResult
    static func applyButton(_ sprite: SKSpriteNode, imageName: String, width: CGFloat) -> Bool {
        guard let tex = GameAssets.texture(imageName) else {
            sprite.isHidden = true
            return false
        }
        sprite.texture = tex
        sprite.size = buttonSize(for: tex, width: width)
        sprite.isHidden = false
        return true
    }

    @discardableResult
    static func applyButton(_ sprite: SKSpriteNode, width: CGFloat) -> Bool {
        applyButton(sprite, imageName: GameAssets.ImageName.uiBtnStartConquest, width: width)
    }

    /// White label with dark outline — readable on busy backgrounds without image panels.
    static func makeOutlinedLabel(
        text: String,
        fontSize: CGFloat,
        bold: Bool = true,
        maxWidth: CGFloat? = nil
    ) -> SKNode {
        let container = SKNode()
        let fontName = bold ? "AvenirNext-Bold" : "AvenirNext-DemiBold"
        let offsets: [(CGFloat, CGFloat)] = [
            (-2, 0), (2, 0), (0, -2), (0, 2),
            (-2, -2), (2, -2), (-2, 2), (2, 2),
        ]

        func makeLayer(color: SKColor, z: CGFloat) -> SKLabelNode {
            let label = SKLabelNode(fontNamed: fontName)
            label.text = text
            label.fontSize = fontSize
            label.fontColor = color
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = z
            if let maxWidth {
                label.preferredMaxLayoutWidth = maxWidth
                label.numberOfLines = 0
            }
            return label
        }

        for (dx, dy) in offsets {
            let outline = makeLayer(color: .black, z: 0)
            outline.alpha = 0.88
            outline.position = CGPoint(x: dx, y: dy)
            container.addChild(outline)
        }

        let main = makeLayer(color: .white, z: 1)
        container.addChild(main)
        return container
    }

    /// Compact translucent panel sized to fit a group of nodes.
    static func makeTranslucentPanel(
        around content: SKNode,
        padding: CGSize = CGSize(width: 20, height: 14),
        cornerRadius: CGFloat = 12,
        fillAlpha: CGFloat = 0.52
    ) -> SKShapeNode {
        let bounds = content.calculateAccumulatedFrame()
        let rect = bounds.insetBy(dx: -padding.width, dy: -padding.height)
        let panel = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
        panel.fillColor = SKColor(white: 0.08, alpha: fillAlpha)
        panel.strokeColor = SKColor(white: 1, alpha: 0.12)
        panel.lineWidth = 1.5
        panel.zPosition = -1
        return panel
    }

    static func styleContentLabel(
        _ label: SKLabelNode,
        fontSize: CGFloat,
        bold: Bool = false,
        maxWidth: CGFloat? = nil
    ) {
        label.fontName = bold ? "AvenirNext-Bold" : "AvenirNext-DemiBold"
        label.fontSize = fontSize
        label.fontColor = .white
        label.alpha = 1
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        if let maxWidth {
            label.preferredMaxLayoutWidth = maxWidth
            label.numberOfLines = 0
        }
        label.zPosition = Z.content
    }
}

