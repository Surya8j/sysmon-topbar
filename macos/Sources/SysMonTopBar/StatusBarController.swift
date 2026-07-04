import AppKit

/// Owns the NSStatusItem: polls samplers on a timer, renders the current view,
/// toggles CPU/RAM on left-click and shows a Quit menu on right-click.
final class StatusBarController: NSObject {
    private static let pollInterval: TimeInterval = 2.0

    private enum View {
        case cpu, ram, gpu
    }

    private let statusItem: NSStatusItem
    private let cpuSampler = CPUSampler()
    private let memorySampler = MemorySampler()
    private let gpuSampler = GPUSampler()
    private var timer: Timer?
    private var currentView: View = .cpu

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        refresh()
        let timer = Timer.scheduledTimer(
            timeInterval: Self.pollInterval,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = Self.pollInterval / 4
        self.timer = timer
    }

    @objc private func tick() {
        refresh()
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            switch currentView {
            case .cpu: currentView = .ram
            case .ram: currentView = gpuSampler.sample() != nil ? .gpu : .cpu
            case .gpu: currentView = .cpu
            }
            refresh()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(
            title: "Quit SysMon TopBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)

        // Attach the menu just for this click so left-clicks keep toggling views.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func refresh() {
        let cores = cpuSampler.sample()
        let mem = memorySampler.sample()
        let gpu = gpuSampler.sample()
        guard let button = statusItem.button else { return }

        button.imagePosition = .imageLeft
        switch currentView {
        case .cpu:
            button.attributedTitle = NSAttributedString()
            button.image = Renderer.cpuImage(cores: cores)
        case .ram:
            button.image = Renderer.ramImage(mem)
            button.attributedTitle = Renderer.ramTitle(mem)
        case .gpu:
            button.image = nil
            button.attributedTitle = Renderer.gpuTitle(utilization: gpu ?? 0)
        }
        button.toolTip = Renderer.tooltip(
            cores: cores, mem: mem, gpu: gpu, gpuCores: gpuSampler.coreCount
        )
    }
}
