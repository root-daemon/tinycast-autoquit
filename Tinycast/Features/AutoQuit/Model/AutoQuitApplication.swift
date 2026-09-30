import Foundation

struct AutoQuitApplication: Identifiable, Sendable {
    let bundleID: String
    let name: String
    let url: URL?
    let minutes: Int?

    var id: String { bundleID }
}
