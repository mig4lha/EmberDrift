import Foundation

enum PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 1 << 0
    static let enemy: UInt32 = 1 << 1
    static let xpOrb: UInt32 = 1 << 2
    static let boss: UInt32 = 1 << 3
    static let bossAttack: UInt32 = 1 << 4
}

enum GameConstants {
    static let runLengthSeconds: TimeInterval = 5 * 60

    static let basePlayerMaxHP: CGFloat = 100
    static let baseMoveSpeed: CGFloat = 240 // points/sec

    static let scuttlerBaseSpeed: CGFloat = 140
    static let scuttlerMaxHP: CGFloat = 10
    static let scuttlerContactDamage: CGFloat = 8

    static let bruteBaseSpeed: CGFloat = 80
    static let bruteMaxHP: CGFloat = 55
    static let bruteContactDamage: CGFloat = 18
}

