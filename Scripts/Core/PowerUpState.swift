import Foundation

struct PowerUpState: Codable {
    var stacks: [PowerUpKind: Int] = [:]

    mutating func stackCount(_ kind: PowerUpKind) -> Int { stacks[kind] ?? 0 }

    mutating func addStack(_ kind: PowerUpKind, cap: Int?) -> Bool {
        let current = stacks[kind] ?? 0
        if let cap, current >= cap { return false }
        stacks[kind] = current + 1
        return true
    }
}

struct InRunModifiers {
    var damageMultiplier: CGFloat = 1.0
    var dotDamagePerSecond: CGFloat = 0
    var attackInterval: TimeInterval = 0.92
    var attackRadius: CGFloat = 159
    var moveSpeedMultiplier: CGFloat = 1.0
    var maxHPBonus: CGFloat = 0
    var damageReduction: CGFloat = 0 // 0..0.3
    var magneticPullRange: CGFloat = 0
    var ashMultiplier: Double = 1.0
}

