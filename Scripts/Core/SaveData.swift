import Foundation

struct SaveData: Codable {
    var ash: Int = 0
    var emberTree: EmberTreeState = .init()
    var totalRuns: Int = 0
    var bestTimeSurvivedSeconds: Int = 0
}

