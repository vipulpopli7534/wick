import Foundation

enum Phase: Equatable {
    case idle
    case focus
    case shortBreak
}

/// Keeps time using an end date, so it stays accurate across sleep and busy CPUs.
final class FocusTimer: NSObject {
    /// Run `WICK_FAST=1 open Wick.app` (or set it in your shell) to test with 25 s / 5 s sessions.
    static let fastMode = ProcessInfo.processInfo.environment["WICK_FAST"] == "1"
    static let focusLength: TimeInterval = fastMode ? 25 : 25 * 60
    static let breakLength: TimeInterval = fastMode ? 5 : 5 * 60

    private(set) var phase: Phase = .idle
    private(set) var isPaused = false
    private var endDate: Date?
    private var pausedRemaining: TimeInterval = 0
    private var ticker: Timer?

    /// Called on every tick and on every state change.
    var onTick: (() -> Void)?
    /// Called when a phase ends. `completed` is false when the user skipped it.
    var onPhaseFinished: ((Phase, Bool) -> Void)?

    var duration: TimeInterval {
        phase == .shortBreak ? Self.breakLength : Self.focusLength
    }

    var remaining: TimeInterval {
        switch phase {
        case .idle: return Self.focusLength
        default:
            if isPaused { return pausedRemaining }
            guard let endDate = endDate else { return 0 }
            return max(0, endDate.timeIntervalSinceNow)
        }
    }

    /// 1.0 = brand-new candle, 0.0 = burnt out.
    var fractionRemaining: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, remaining / duration))
    }

    func start(_ newPhase: Phase) {
        guard newPhase != .idle else { reset(); return }
        phase = newPhase
        isPaused = false
        endDate = Date().addingTimeInterval(duration)
        startTicker()
        onTick?()
    }

    func pause() {
        guard phase != .idle, !isPaused else { return }
        pausedRemaining = remaining
        isPaused = true
        endDate = nil
        onTick?()
    }

    func resume() {
        guard phase != .idle, isPaused else { return }
        endDate = Date().addingTimeInterval(pausedRemaining)
        isPaused = false
        onTick?()
    }

    func skip() {
        guard phase != .idle else { return }
        finish(completed: false)
    }

    func reset() {
        stopTicker()
        phase = .idle
        isPaused = false
        endDate = nil
        onTick?()
    }

    private func startTicker() {
        stopTicker()
        // Half-second ticks so the last-minute flame flicker looks alive.
        let t = Timer(timeInterval: 0.5, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common) // keeps ticking while the menu is open
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    @objc private func tick() {
        guard phase != .idle else { return }
        if !isPaused && remaining <= 0 {
            finish(completed: true)
        } else {
            onTick?()
        }
    }

    private func finish(completed: Bool) {
        let finished = phase
        stopTicker()
        phase = .idle
        isPaused = false
        endDate = nil
        onPhaseFinished?(finished, completed)
    }
}
