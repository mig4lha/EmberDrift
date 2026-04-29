import Foundation

struct RunStats: Codable {
    var timeSurvivedSeconds: Int
    var enemiesKilledByType: [EnemyKind: Int]
    var finalLevel: Int
    var powerUpsTaken: [PowerUpKind]
    var ashEarned: Int
}

