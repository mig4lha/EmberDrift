import SpriteKit

extension SKNode {
    private static let damageFlashName = "damageFlashOverlay"

    /// Brief red overlay when this node takes damage.
    func showDamageFlash(radius: CGFloat, duration: TimeInterval = 0.5) {
        childNode(withName: Self.damageFlashName)?.removeFromParent()

        let overlay = SKShapeNode(circleOfRadius: radius)
        overlay.name = Self.damageFlashName
        overlay.fillColor = SKColor(red: 1, green: 0.12, blue: 0.08, alpha: 0.52)
        overlay.strokeColor = SKColor(red: 1, green: 0.35, blue: 0.25, alpha: 0.35)
        overlay.lineWidth = 1.5
        overlay.zPosition = 200
        overlay.alpha = 1
        addChild(overlay)

        overlay.run(.sequence([
            .fadeAlpha(to: 0, duration: duration),
            .removeFromParent(),
        ]))
    }
}
