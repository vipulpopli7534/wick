import AppKit

@main
enum WickApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // lives in the menu bar only, no Dock icon
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
