import Foundation

struct EmberTreeState: Codable, Equatable {
    // Repeatable upgrades
    var temperedBody: Int = 0  // +10 max HP, cap 5
    var hotterCore: Int = 0    // +8% damage, cap 4
    var swiftDrift: Int = 0    // +5% move speed, cap 3
    var emberHoard: Int = 0    // +10% Ash earned, cap 5
    var stoked: Int = 0        // +6% attack speed, cap 3

    // Unlocks
    var secondWind: Bool = false
    var volatileStart: Bool = false
    var kindlingCache: Bool = false
    var twinOffering: Bool = false
    var ashenEcho: Bool = false
}

