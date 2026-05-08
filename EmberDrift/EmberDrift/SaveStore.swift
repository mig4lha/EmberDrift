import Foundation

final class SaveStore {
    static let shared = SaveStore()

    private let defaults = UserDefaults.standard
    private let ashKey = "emberdrift.ash"

    var ash: Int {
        get { defaults.integer(forKey: ashKey) }
        set { defaults.set(newValue, forKey: ashKey) }
    }
}

