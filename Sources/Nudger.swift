import AppKit
import UserNotifications

/// Silent nudges only: trackpad haptics and soundless notification banners.
@MainActor
final class Nudger: NSObject, UNUserNotificationCenterDelegate {
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        // .alert only — Wick never asks for sound.
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil // silent on purpose
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// A short "thump-thump-thump" on the Force Touch trackpad.
    /// macOS only delivers it while a finger is resting on the trackpad.
    func hapticTap(times: Int = 3) {
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
        }
    }

    // Show banners even though Wick is technically the active app.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
