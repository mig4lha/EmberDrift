import Foundation

enum PowerUpKind: String, CaseIterable, Hashable {
    // Offensive
    case scorch
    case afterburn
    case twinFlame
    case eruption
    case widerReach
    case rapidCycle
    case emberBolt

    // Defensive
    case emberShell
    case heatSink
    case rekindle

    // Utility
    case draft
    case magneticPull
    case glowingCoals
    case kindlingBurst
    case ashTithe
    case overload

    var maxStacks: Int? {
        switch self {
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

    var isUnique: Bool {
        switch self {
        case .twinFlame, .emberShell, .rekindle, .ashTithe, .overload:
            return true
        default:
            return false
        }
    }

    var title: String {
        switch self {
        case .scorch: return "SCORCH"
        case .afterburn: return "AFTERBURN"
        case .twinFlame: return "TWIN FLAME"
        case .eruption: return "ERUPTION"
        case .widerReach: return "WIDER REACH"
        case .rapidCycle: return "RAPID CYCLE"
        case .emberBolt: return "EMBER BOLT"
        case .emberShell: return "EMBER SHELL"
        case .heatSink: return "HEAT SINK"
        case .rekindle: return "REKINDLE"
        case .draft: return "DRAFT"
        case .magneticPull: return "MAGNETIC PULL"
        case .glowingCoals: return "GLOWING COALS"
        case .kindlingBurst: return "KINDLING BURST"
        case .ashTithe: return "ASH TITHE"
        case .overload: return "OVERLOAD"
        }
    }

    var subtitle: String {
        switch self {
        case .scorch: return "+12% damage (stackable)"
        case .afterburn: return "Burn enemies for 3s (stackable)"
        case .twinFlame: return "+28% damage (unique)"
        case .eruption: return "Kills may erupt (stackable)"
        case .widerReach: return "+12% ring radius (stackable)"
        case .rapidCycle: return "Attack faster (stackable)"
        case .emberBolt: return "Bolt volley: 2/4/8 shots (stackable)"
        case .emberShell: return "One-hit shield, regen 15s"
        case .heatSink: return "+30 max HP (stackable)"
        case .rekindle: return "Revive once at 40% HP"
        case .draft: return "+20% move speed (stackable)"
        case .magneticPull: return "Pull XP orbs from farther"
        case .glowingCoals: return "+8% XP earned (stackable)"
        case .kindlingBurst: return "Immediately gain another pick"
        case .ashTithe: return "+50% Ash this run"
        case .overload: return "Next pick shows 4 cards"
        }
    }
}
