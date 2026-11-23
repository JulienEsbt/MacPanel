import AppKit
import Carbon
import SwiftUI

@main
enum MacPanelApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let monitor = SystemMonitor()
    private let controls = SystemControls()
    private let awake = AwakeSession()
    private let login = LoginSettings()
    private let disks = DiskController()
    private let displays = DisplayController()
    private let shortcut = PanelShortcut()
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "MacPanel")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePanel)
            button.setAccessibilityLabel("MacPanel — commandes rapides et suivi système")
            button.toolTip = "MacPanel"
        }
        popover.contentViewController = NSHostingController(rootView: PanelView(monitor: monitor,
            controls: controls, awake: awake, login: login, disks: disks, displays: displays, shortcut: shortcut))
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        shortcut.start { [weak self] in self?.togglePanel() }
        let screenChanges = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.displays.clearShades()
                    if self?.popover.isShown == true { self?.displays.refresh() }
                }
            }
        observers.append((.default, screenChanges))

        let workspace = NSWorkspace.shared.notificationCenter
        let sleep = workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.endSession() }
        }
        observers.append((workspace, sleep))
        let distributed = DistributedNotificationCenter.default()
        let keyboard = distributed.addObserver(forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.shortcut.keyboardLayoutChanged() }
            }
        observers.append((distributed, keyboard))
        let lock = distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.endSession() }
        }
        observers.append((distributed, lock))
    }

    @objc private func togglePanel() {
        if popover.isShown { popover.performClose(nil) }
        else { showPanel() }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        // macOS 27 can place a popover above the external screen when screens have
        // different vertical origins. Use the status item's actual screen coordinates.
        DispatchQueue.main.async { [weak self] in self?.positionPanel() }
    }

    private func positionPanel() {
        guard popover.isShown, let button = statusItem.button, let barWindow = button.window,
            let window = popover.contentViewController?.view.window else { return }
        let anchor = barWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: anchor.midX, y: anchor.midY)) }
            ?? barWindow.screen ?? NSScreen.main
        guard let screen else { return }
        window.setFrameOrigin(PanelPlacement.origin(size: window.frame.size, anchor: anchor, visible: screen.visibleFrame))
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    func popoverDidShow(_ notification: Notification) {
        monitor.start()
        disks.start()
        displays.refresh()
        controls.refresh()
        login.refresh()
    }

    func popoverDidClose(_ notification: Notification) {
        monitor.stop()
        disks.stop()
        displays.stopReading()
    }

    private func endSession() {
        awake.stop()
        monitor.stop()
        disks.stop()
        displays.stopReading()
        popover.performClose(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        endSession()
        shortcut.stop()
        displays.stop()
        for (center, token) in observers { center.removeObserver(token) }
    }
}
