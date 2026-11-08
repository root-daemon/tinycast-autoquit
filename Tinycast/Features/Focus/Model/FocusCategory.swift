import Foundation

/// A curated starting point; a bundle ID that is not installed simply never matches.
struct FocusCategory: Identifiable, Sendable {
    let id: String
    let nameResource: LocalizedStringResource
    let symbol: String
    let bundleIDs: Set<String>

    var name: String { String(localized: nameResource) }

    static func category(id: String) -> FocusCategory? {
        builtIn.first { $0.id == id }
    }

    static let builtIn: [FocusCategory] = [
        FocusCategory(
            id: "social", nameResource: "Social & Messaging", symbol: "bubble.left.and.bubble.right",
            bundleIDs: [
                "com.apple.MobileSMS", "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram",
                "org.whispersystems.signal-desktop", "com.hnc.Discord", "com.facebook.archon",
                "com.tapbots.Ivory.mac", "com.thomasricouard.IceCubesApp", "com.apple.FaceTime"
            ]),
        FocusCategory(
            id: "work-chat", nameResource: "Work Chat", symbol: "person.2",
            bundleIDs: [
                "com.tinyspeck.slackmacgap", "com.microsoft.teams2", "com.microsoft.teams",
                "us.zoom.xos", "com.linear", "com.figma.Desktop.comments"
            ]),
        FocusCategory(
            id: "email", nameResource: "Email", symbol: "envelope",
            bundleIDs: [
                "com.apple.mail", "com.microsoft.Outlook", "com.readdle.SparkDesktop",
                "com.readdle.SparkDesktop.appstore", "com.mimestream.Mimestream",
                "com.superhuman.electron", "it.bloop.airmail2"
            ]),
        FocusCategory(
            id: "entertainment", nameResource: "Entertainment", symbol: "play.tv",
            bundleIDs: [
                "com.apple.Music", "com.apple.TV", "com.apple.podcasts", "com.spotify.client",
                "com.colliderli.iina", "org.videolan.vlc", "com.apple.iBooksX", "com.apple.Photos"
            ]),
        FocusCategory(
            id: "news", nameResource: "News & Reading", symbol: "newspaper",
            bundleIDs: [
                "com.apple.news", "com.apple.stocks", "com.ranchero.NetNewsWire-Evergreen",
                "com.reederapp.5.macOS", "com.reederapp.macOS"
            ]),
        FocusCategory(
            id: "gaming", nameResource: "Gaming", symbol: "gamecontroller",
            bundleIDs: [
                "com.valvesoftware.steam", "com.epicgames.EpicGamesLauncher", "com.gog.galaxy",
                "net.battle.bootstrapper", "net.battle.app", "com.apple.Chess", "com.apple.games",
                "com.mojang.minecraftlauncher"
            ])
    ]

    /// Never quit, whatever the mode: without them an allow list could lock the user out.
    static let alwaysAllowed: Set<String> = [
        "com.apple.finder", "com.apple.systempreferences", "com.apple.ActivityMonitor",
        "com.apple.loginwindow", "com.apple.SecurityAgent", "com.apple.dock",
        "com.apple.controlcenter", "com.apple.Spotlight", "com.apple.ScreenSharing"
    ]
}
