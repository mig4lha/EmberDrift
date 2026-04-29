import Foundation

extension Int {
    func formatAsMMSS() -> String {
        let m = self / 60
        let s = self % 60
        return String(format: "%d:%02d", m, s)
    }
}

