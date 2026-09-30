import Foundation

struct AutoQuitPaletteItem: Identifiable {
    enum Action {
        case toggle
        case edit(String)
        case delay(Int)
        case custom
        case remove
    }

    let id: String
    let title: String
    let subtitle: String
    let trailing: String
    let symbol: String
    var appURL: URL?
    var section: String?
    var isCurrent = false
    let action: Action
}
