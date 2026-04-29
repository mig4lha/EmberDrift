import SpriteKit

final class XPSystem {
    private weak var parent: SKNode?
    private var orbPool: [XPOrbNode] = []
    private var activeOrbs: [XPOrbNode] = []

    private(set) var level: Int = 1
    private(set) var currentXP: Int = 0

    var xpMultiplier: Double = 1.0

    func xpRequiredForNextLevel() -> Int {
        // Baseline table for first 10 levels; after that, extend gently.
        let table = [0, 20, 35, 55, 80, 110, 145, 185, 230, 280] // index is next level
        if level < table.count - 1 {
            return Int(Double(table[level]) * xpMultiplier)
        }
        let base = 280 + (level - 9) * 70
        return Int(Double(base) * xpMultiplier)
    }

    init(parent: SKNode) {
        self.parent = parent
    }

    func spawnOrb(at position: CGPoint, xpValue: Int) {
        guard let parent else { return }
        let orb = acquireOrb()
        orb.position = position
        orb.reset(xpValue: xpValue)
        parent.addChild(orb)
        activeOrbs.append(orb)
    }

    func updateOrbsTowardPlayer(playerPos: CGPoint, dt: TimeInterval, pullRange: CGFloat) {
        guard pullRange > 0 else { return }
        for orb in activeOrbs where !orb.isHidden {
            let delta = playerPos - orb.position
            let dist = delta.length
            guard dist < pullRange else { continue }
            let strength = (1 - (dist / pullRange)).clamped(0, 1)
            let vel = delta.normalized() * (260 + 540 * strength)
            orb.position = orb.position + (vel * dt)
        }
    }

    func collectOrb(_ orb: XPOrbNode) -> Bool {
        currentXP += orb.xpValue
        releaseOrb(orb)

        let required = xpRequiredForNextLevel()
        if currentXP >= required {
            currentXP -= required
            level += 1
            return true
        }
        return false
    }

    private func acquireOrb() -> XPOrbNode {
        if let orb = orbPool.popLast() { return orb }
        return XPOrbNode()
    }

    private func releaseOrb(_ orb: XPOrbNode) {
        orb.removeAllActions()
        orb.isHidden = true
        orb.physicsBody?.categoryBitMask = PhysicsCategory.none
        orb.physicsBody?.contactTestBitMask = PhysicsCategory.none
        orb.position = CGPoint(x: 999_999, y: 999_999)
        orbPool.append(orb)
        // keep array small
        if let idx = activeOrbs.firstIndex(where: { $0 === orb }) {
            activeOrbs.remove(at: idx)
        }
    }
}

