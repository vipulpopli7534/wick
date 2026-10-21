import AppKit

/// The big candle + time shown at the top of the menu.
final class HeaderView: NSView {
    private let imageView = NSImageView()
    private let timeLabel = NSTextField(labelWithString: "25:00")
    private let subLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 250, height: 96))
        imageView.frame = NSRect(x: 18, y: 10, width: 64, height: 76)
        imageView.imageScaling = .scaleProportionallyUpOrDown

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .medium)
        timeLabel.frame = NSRect(x: 94, y: 44, width: 150, height: 40)

        subLabel.font = .systemFont(ofSize: 12)
        subLabel.textColor = .secondaryLabelColor
        subLabel.frame = NSRect(x: 96, y: 20, width: 150, height: 18)

        addSubview(imageView)
        addSubview(timeLabel)
        addSubview(subLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func update(phase: Phase, remaining: TimeInterval, fraction: Double, paused: Bool, flicker: Bool) {
        timeLabel.stringValue = TimeFormat.clock(remaining)
        switch phase {
        case .idle:
            imageView.image = CandleRenderer.image(size: imageView.frame.size, fraction: 1, lit: false)
            subLabel.stringValue = "Click to light a candle"
        case .focus:
            imageView.image = CandleRenderer.image(size: imageView.frame.size, fraction: fraction, lit: !paused, flicker: flicker)
            subLabel.stringValue = paused ? "Paused" : "Focus. No distractions."
        case .shortBreak:
            let config = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
            imageView.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Break")?
                .withSymbolConfiguration(config)
            imageView.contentTintColor = .labelColor
            subLabel.stringValue = paused ? "Break paused" : "Stand up, drink water"
        }
    }
}

enum TimeFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
