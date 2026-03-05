import Foundation

enum SharedDefaults {
    static let suiteName = "group.vvstudio.co.Nomad-toolkit"

    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
