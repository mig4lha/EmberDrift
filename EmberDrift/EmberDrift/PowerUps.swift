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
        case .scorch: return "DEPRECATE API"
        case .afterburn: return "FORCE QUIT"
        case .twinFlame: return "M1 PRO"
        case .eruption: return "KERNEL PANIC"
        case .widerReach: return "ECOSYSTEM LOCK"
        case .rapidCycle: return "OVER-THE-AIR"
        case .emberBolt: return "ICLOUD BLAST"
        case .emberShell: return "FIND MY SHIELD"
        case .heatSink: return "BATTERY ENVELOPE"
        case .rekindle: return "TIME MACHINE"
        case .draft: return "TRACKPAD GESTURE"
        case .magneticPull: return "AIRDROP MAGNET"
        case .glowingCoals: return "APP STORE BOOST"
        case .kindlingBurst: return "WWDC KEYNOTE"
        case .ashTithe: return "MARKET SURGE"
        case .overload: return "PRO UPGRADE"
        }
    }

    var subtitle: String {
        switch self {
        case .scorch: return "+12% damage vs rival OS (stackable)"
        case .afterburn: return "Glitch enemies for 3s (stackable)"
        case .twinFlame: return "+28% damage (unique silicon)"
        case .eruption: return "Kills may crash rivals (stackable)"
        case .widerReach: return "+12% attack radius (stackable)"
        case .rapidCycle: return "Deploy attacks faster (stackable)"
        case .emberBolt: return "Sync blast: 2/4/8 shots (stackable)"
        case .emberShell: return "One-hit shield, regen 15s"
        case .heatSink: return "+30 max HP (stackable)"
        case .rekindle: return "Restore once at 40% HP"
        case .draft: return "+20% move speed (stackable)"
        case .magneticPull: return "Pull upgrades from farther"
        case .glowingCoals: return "+8% XP earned (stackable)"
        case .kindlingBurst: return "Immediately gain another pick"
        case .ashTithe: return "+50% Market Share this run"
        case .overload: return "Next pick shows 4 cards"
        }
    }
}
