import Cocoa
import Sparkle

/// Automatic updates through Sparkle. The feed and the public signing key live in Info.plist
/// (SUFeedURL, SUPublicEDKey); every update zip is EdDSA-signed and checked before installing.
/// Behavior: check once a day and always ask before installing.
@MainActor
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    static let shared = Updater()

    private var controller: SPUStandardUpdaterController!

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    }

    /// Starts the updater (call once at launch).
    func start() { _ = controller }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    // MARK: - SPUStandardUserDriverDelegate

    // A menu bar app has no Dock icon, so a scheduled update would otherwise open its window
    // behind whatever the user is doing. Bring the app forward whenever Sparkle shows an update.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard handleShowingUpdate else { return }
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }
}
