import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let timer = FocusTimer()
    private let nudger = Nudger()
    private let header = HeaderView()

    private var flickerOn = false
    private var wiggleTimer: Timer?
    private var wiggleFrame = 0
    private var wiggleFraction: Double = 0

    private var showCountdown: Bool {
        get { UserDefaults.standard.object(forKey: "showCountdown") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showCountdown") }
    }

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.toolTip = "Wick: click to light a candle, right-click for options"
        }

        timer.onTick = { [weak self] in self?.refresh() }
        timer.onPhaseFinished = { [weak self] phase, completed in
            self?.phaseFinished(phase, completed: completed)
        }

        nudger.requestPermission()
        refresh()
    }

    // MARK: - Clicks

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let wasNudging = wiggleTimer != nil
        stopWiggle()

        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isRightClick {
            showMenu()
            return
        }
        if wasNudging { return } // the first click just says "I saw it"

        switch timer.phase {
        case .idle:
            timer.start(.focus)
        default:
            if timer.isPaused { timer.resume() } else { showMenu() }
        }
    }

    private func showMenu() {
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil) // opens the menu and blocks until it closes
        statusItem.menu = nil                // so the next left-click reaches our action again
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        updateHeader()
        let headerItem = NSMenuItem()
        headerItem.view = header
        menu.addItem(headerItem)
        menu.addItem(.separator())

        if timer.phase == .idle {
            menu.addItem(item("Light a candle (\(Int(FocusTimer.focusLength / 60)) min)", #selector(startFocus), key: "l"))
        } else {
            if timer.isPaused {
                menu.addItem(item("Resume", #selector(resume), key: "p"))
            } else {
                menu.addItem(item("Pause", #selector(pause), key: "p"))
            }
            menu.addItem(item(timer.phase == .focus ? "Skip to break" : "Skip break", #selector(skip), key: "s"))
            menu.addItem(item("Blow it out (reset)", #selector(reset), key: "r"))
        }

        menu.addItem(.separator())
        let today = NSMenuItem(title: Streak.todayText, action: nil, keyEquivalent: "")
        today.isEnabled = false
        menu.addItem(today)
        let total = NSMenuItem(title: "All-time: \(Streak.total)", action: nil, keyEquivalent: "")
        total.isEnabled = false
        menu.addItem(total)

        menu.addItem(.separator())
        let countdown = item("Show countdown in menu bar", #selector(toggleCountdown))
        countdown.state = showCountdown ? .on : .off
        menu.addItem(countdown)
        let login = item("Open at login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Quit Wick", #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    // MARK: - Menu actions

    @objc private func startFocus() { timer.start(.focus) }
    @objc private func pause() { timer.pause() }
    @objc private func resume() { timer.resume() }
    @objc private func skip() { timer.skip() }
    @objc private func reset() { timer.reset() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleCountdown() {
        showCountdown.toggle()
        refresh()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login setting"
            alert.informativeText = "Move Wick into your Applications folder and try again.\n\n\(error.localizedDescription)"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    // MARK: - Phases

    private func phaseFinished(_ phase: Phase, completed: Bool) {
        switch phase {
        case .focus:
            if completed {
                Streak.increment()
                nudger.notify(title: "Candle burnt out 🕯️",
                              body: "Nice focus! Stand up, stretch and drink some water. Your 5-minute break has started.")
                timer.start(.shortBreak)
                startWiggle(fraction: 0)
            } else {
                timer.start(.shortBreak)
            }
        case .shortBreak:
            if completed {
                nudger.notify(title: "Break's over", body: "Ready to light another candle?")
                startWiggle(fraction: 1)
            }
            refresh()
        case .idle:
            refresh()
        }
    }

    // MARK: - Drawing

    private func refresh() {
        guard let button = statusItem?.button else { return }
        flickerOn.toggle()

        if wiggleTimer == nil {
            button.image = currentIcon()
        }
        let showTime = showCountdown && timer.phase != .idle
        button.title = showTime ? " " + TimeFormat.clock(timer.remaining) : ""
        updateHeader()
    }

    private var isLastMinute: Bool {
        timer.phase == .focus && !timer.isPaused && timer.remaining <= 60
    }

    private func currentIcon() -> NSImage {
        switch timer.phase {
        case .idle:
            return CandleRenderer.image(fraction: 1, lit: false)
        case .focus:
            return CandleRenderer.image(fraction: timer.fractionRemaining,
                                        lit: !timer.isPaused,
                                        flicker: isLastMinute && flickerOn)
        case .shortBreak:
            let cup = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Break") ?? NSImage()
            cup.isTemplate = true
            return cup
        }
    }

    private func updateHeader() {
        header.update(phase: timer.phase,
                      remaining: timer.remaining,
                      fraction: timer.fractionRemaining,
                      paused: timer.isPaused,
                      flicker: isLastMinute && flickerOn)
    }

    // MARK: - Wiggle nudge

    /// Shakes the candle in bursts (with a trackpad tap each burst) until clicked, for up to ~45 s.
    private func startWiggle(fraction: Double) {
        wiggleTimer?.invalidate()
        wiggleFrame = 0
        wiggleFraction = fraction
        let t = Timer(timeInterval: 0.06, target: self, selector: #selector(wiggleStep), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        wiggleTimer = t
    }

    @objc private func wiggleStep() {
        wiggleFrame += 1
        let burst = wiggleFrame % 30 // 15 frames shaking, 15 frames resting
        let tilt: CGFloat = burst < 15 ? sin(CGFloat(wiggleFrame) * 1.4) * 0.3 : 0
        statusItem.button?.image = CandleRenderer.image(fraction: wiggleFraction, lit: false, tilt: tilt)
        if burst == 0 { nudger.hapticTap() }
        if wiggleFrame > 30 * 25 { stopWiggle() }
    }

    private func stopWiggle() {
        guard wiggleTimer != nil else { return }
        wiggleTimer?.invalidate()
        wiggleTimer = nil
        refresh()
    }
}
