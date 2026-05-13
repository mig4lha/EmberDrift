import SpriteKit

final class XPSystem {
    struct Snapshot {
        let level: Int
        let xp: Int
        let xpToNext: Int
        let pendingLevelUps: Int
    }

    private(set) var level: Int = 1
    private(set) var xp: Int = 0
    private(set) var pendingLevelUps: Int = 0

    private var xpOrbs: [XPOrbNode] = []
    private let baseOrbPullRadius: CGFloat = 90
    private var orbPullRadiusMultiplier: CGFloat = 1.0

    func snapshot() -> Snapshot {
        Snapshot(level: level, xp: xp, xpToNext: xpNeededForNextLevel(), pendingLevelUps: pendingLevelUps)
    }

    func setLevelForDebug(_ newLevel: Int) {
        level = max(1, newLevel)
    }

    func addPendingLevelUps(_ count: Int) {
        pendingLevelUps += max(0, count)
    }

    func consumeOnePendingLevelUp() {
        pendingLevelUps = max(0, pendingLevelUps - 1)
    }

    func spawnOrb(in world: SKNode, at pos: CGPoint, value: Int) {
        let orb = XPOrbNode(xpValue: value)
        orb.position = pos
        world.addChild(orb)
        xpOrbs.append(orb)
    }

    func onOrbCollected(_ orb: XPOrbNode) {
        xpOrbs.removeAll(where: { $0 === orb })
    }

    func clearOrbs() {
        for orb in xpOrbs { orb.removeFromParent() }
        xpOrbs.removeAll(keepingCapacity: true)
    }

    func addXP(_ amount: Int) {
        xp += max(0, amount)
        while xp >= xpNeededForNextLevel() {
            xp -= xpNeededForNextLevel()
            level += 1
            pendingLevelUps += 1
        }
    }

    func setMagnetStacks(_ stacks: Int) {
        if stacks >= 2 {
            orbPullRadiusMultiplier = 3.0
        } else if stacks >= 1 {
            orbPullRadiusMultiplier = 2.0
        } else {
            orbPullRadiusMultiplier = 1.0
        }
    }

    func stepOrbMagnet(dt: TimeInterval, playerPosition: CGPoint) {
        guard dt > 0 else { return }
        let pullRadius = baseOrbPullRadius * orbPullRadiusMultiplier
        let pullRadiusSq = pullRadius * pullRadius
        let pullSpeed: CGFloat = 520

        xpOrbs.removeAll(where: { $0.parent == nil })

        for orb in xpOrbs {
            let dx = playerPosition.x - orb.position.x
            let dy = playerPosition.y - orb.position.y
            let distSq = dx * dx + dy * dy
            guard distSq <= pullRadiusSq, distSq > 0.0001 else { continue }
            let dist = sqrt(distSq)
            let step = min(dist, pullSpeed * CGFloat(dt))
            orb.position.x += (dx / dist) * step
            orb.position.y += (dy / dist) * step
        }
    }

    private func xpNeededForNextLevel() -> Int {
        switch level {
        case 1: return 20
        case 2: return 35
        case 3: return 55
        case 4: return 80
        case 5: return 110
        case 6: return 145
        case 7: return 185
        case 8: return 230
        case 9: return 280
        default:
            return 280 + (level - 9) * 60
        }
    }
}

