import AppKit

/// Draws the menu bar content: per-core CPU bars and the bracket-style RAM view,
/// using the htop-like gradient from the original GNOME extension.
enum Renderer {
    // MARK: - Colors

    static func color(for usage: Double) -> NSColor {
        switch usage {
        case ..<0.30: return .systemGreen
        case ..<0.60: return .systemCyan
        case ..<0.85: return .systemYellow
        default: return .systemRed
        }
    }

    // MARK: - CPU view (one vertical bar per core)

    static func cpuImage(cores: [Double]) -> NSImage {
        let barWidth: CGFloat = 3
        let gap: CGFloat = 2
        let height: CGFloat = 16
        let count = max(cores.count, 1)
        let width = CGFloat(count) * (barWidth + gap) - gap

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            for (i, usage) in cores.enumerated() {
                let x = CGFloat(i) * (barWidth + gap)
                let track = NSRect(x: x, y: 0, width: barWidth, height: height)
                NSColor.tertiaryLabelColor.setFill()
                NSBezierPath(roundedRect: track, xRadius: 1, yRadius: 1).fill()

                let fillHeight = max(1.5, height * CGFloat(min(max(usage, 0), 1)))
                let fill = NSRect(x: x, y: 0, width: barWidth, height: fillHeight)
                color(for: usage).setFill()
                NSBezierPath(roundedRect: fill, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - RAM view (compact gauge + used amount)

    static func ramImage(_ mem: MemoryStats) -> NSImage {
        let width: CGFloat = 24
        let height: CGFloat = 16
        let gaugeHeight: CGFloat = 7
        let y = (height - gaugeHeight) / 2
        let radius = gaugeHeight / 2
        let fraction = CGFloat(min(max(mem.usedFraction, 0), 1))

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let track = NSRect(x: 0, y: y, width: width, height: gaugeHeight)
            NSColor.tertiaryLabelColor.setFill()
            NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius).fill()

            let fill = NSRect(x: 0, y: y, width: max(gaugeHeight, width * fraction), height: gaugeHeight)
            color(for: mem.usedFraction).setFill()
            NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    static func ramTitle(_ mem: MemoryStats) -> NSAttributedString {
        NSAttributedString(string: " " + format(bytes: mem.used), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ])
    }

    // MARK: - Tooltip

    static func tooltip(cores: [Double], mem: MemoryStats) -> String {
        var lines: [String] = []

        if !cores.isEmpty {
            let avg = cores.reduce(0, +) / Double(cores.count)
            lines.append(String(format: "CPU %.0f%% avg", avg * 100))
            for chunk in stride(from: 0, to: cores.count, by: 4) {
                let row = (chunk..<min(chunk + 4, cores.count)).map { i in
                    String(format: "C%-2d %3.0f%%", i, cores[i] * 100)
                }
                lines.append("  " + row.joined(separator: "  "))
            }
        }

        lines.append(String(
            format: "Mem %@ / %@ (%.0f%%)",
            format(bytes: mem.used), format(bytes: mem.total), mem.usedFraction * 100
        ))
        lines.append("Swp \(format(bytes: mem.swapUsed)) / \(format(bytes: mem.swapTotal))")
        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting

    static func format(bytes: UInt64) -> String {
        let gib = Double(bytes) / 1_073_741_824
        if gib >= 10 { return String(format: "%.0fG", gib) }
        if gib >= 1 { return String(format: "%.1fG", gib) }
        let mib = Double(bytes) / 1_048_576
        return String(format: "%.0fM", mib)
    }
}
