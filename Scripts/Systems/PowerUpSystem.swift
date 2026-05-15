import Foundation

struct PowerUpDefinition {
    let kind: PowerUpKind
    let cap: Int?
}

final class PowerUpSystem {
    private(set) var state = PowerUpState()
    private var allowedKinds: Set<PowerUpKind> = Set(PowerUpKind.allCases)

    func configureAllowedKinds(_ kinds: Set<PowerUpKind>) {
        allowedKinds = kinds
    }

    func drawOptions(count: Int) -> [PowerUpKind] {
        var pool = availablePool()
        if pool.isEmpty { return [] }

        if pool.count == 1, pool.first == .kindlingBurst {
            return []
        }

        var result: [PowerUpKind] = []
        for _ in 0..<count {
            if pool.isEmpty { break }
            let idx = Int.random(in: 0..<pool.count)
            result.append(pool.remove(at: idx))
        }
        return result
    }

    func apply(_ kind: PowerUpKind, modifiers: inout InRunModifiers, player: PlayerNode) {
        let cap = capFor(kind)
        let didAdd = state.addStack(kind, cap: cap)
        guard didAdd else { return }

        let stacks = state.stacks[kind] ?? 0
        switch kind {
        case .scorch:
            modifiers.damageMultiplier *= 1.12
        case .afterburn:
            modifiers.dotDamagePerSecond = CGFloat(stacks) * 3
        case .twinFlame:
            modifiers.damageMultiplier *= 1.28
        case .eruption:
            modifiers.damageMultiplier *= (stacks == 1 ? 1.02 : 1.04)
        case .widerReach:
            modifiers.attackRadius *= 1.12
        case .rapidCycle:
            modifiers.attackInterval *= 0.88
        case .emberBolt:
            break
        case .emberShell:
            break
        case .heatSink:
            modifiers.maxHPBonus += 30
            player.maxHP += 30
            player.healToFull()
        case .rekindle:
            break
        case .draft:
            modifiers.moveSpeedMultiplier *= 1.2
        case .magneticPull:
            modifiers.magneticPullRange = (stacks == 1) ? 180 : 260
        case .glowingCoals:
            break
        case .kindlingBurst:
            break
        case .ashTithe:
            modifiers.ashMultiplier *= 1.5
        case .overload:
            break
        }
    }

    func isExhausted() -> Bool {
        availablePool().isEmpty
    }

    private func availablePool() -> [PowerUpKind] {
        var kinds = PowerUpKind.allCases
            .filter { allowedKinds.contains($0) }
            .filter { $0 != .kindlingBurst }

        kinds.removeAll { kind in
            if let cap = capFor(kind) {
                return (state.stacks[kind] ?? 0) >= cap
            }
            return false
        }

        if !kinds.isEmpty {
            if allowedKinds.contains(.kindlingBurst) {
                kinds.append(.kindlingBurst)
            }
        }

        return kinds
    }

    private func capFor(_ kind: PowerUpKind) -> Int? {
        switch kind {
        case .scorch: return 2
        case .afterburn: return 3
        case .twinFlame: return 1
        case .eruption: return 2
        case .widerReach: return 2
        case .rapidCycle: return 3
        case .emberBolt: return 3
        case .emberShell: return 1
        case .heatSink: return 3
        case .rekindle: return 1
        case .draft: return 3
        case .magneticPull: return 2
        case .glowingCoals: return 3
        case .kindlingBurst: return nil
        case .ashTithe: return 1
        case .overload: return 1
        }
    }
}
