import Foundation

final class SaveStore {
    static let shared = SaveStore()

    private let key = "emberdrift.savedata.v1"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> SaveData {
        guard let data = defaults.data(forKey: key) else { return SaveData() }
        return (try? decoder.decode(SaveData.self, from: data)) ?? SaveData()
    }

    func save(_ save: SaveData) {
        guard let data = try? encoder.encode(save) else { return }
        defaults.set(data, forKey: key)
    }

    func update(_ mutate: (inout SaveData) -> Void) {
        var current = load()
        mutate(&current)
        save(current)
    }
}

