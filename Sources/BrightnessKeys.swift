import Carbon
import Combine
import Foundation

struct BrightnessStep {
    static func nextLevel(_ current: Double, direction: Int, software: Bool) -> Double? {
        guard current.isFinite, (0...1).contains(current), (direction == 1 || direction == -1) else { return nil }
        return min(1, max(software ? 0.2 : 0, current + Double(direction) / 16))
    }
}

// Read only registered hot-key identifiers, never the system keyboard event stream.
func registeredHotKeyID(_ event: EventRef?, signature: OSType) -> UInt32? {
    guard let event else { return nil }
    var id = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr, id.signature == signature else { return nil }
    return id.id
}

@MainActor
final class BrightnessKeys: ObservableObject {
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "externalBrightnessKeys")
    @Published private(set) var active = false
    @Published private(set) var error: String?
    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private weak var displays: DisplayController?

    func start(displays: DisplayController) {
        self.displays = displays
        resume()
    }

    func configure(_ enabled: Bool) {
        self.enabled = enabled
        UserDefaults.standard.set(enabled, forKey: "externalBrightnessKeys")
        resume()
    }

    func resume() {
        guard enabled else { suspend(); error = nil; return }
        guard !active else { return }
        suspend()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let id = registeredHotKeyID(event, signature: 0x4D504C42), (1...2).contains(id) else {
                return OSStatus(eventNotHandledErr)
            }
            let owner = Unmanaged<BrightnessKeys>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                guard owner.active else { return }
                owner.displays?.adjustExternal(id == 1 ? 1 : -1)
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { fail(); return }
        for (id, key) in [(UInt32(1), UInt32(kVK_UpArrow)), (UInt32(2), UInt32(kVK_DownArrow))] {
            var hotKey: EventHotKeyRef?
            let result = RegisterEventHotKey(key, UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x4D504C42, id: id),
                                            GetApplicationEventTarget(), 0, &hotKey)
            guard result == noErr, let hotKey else { fail(); return }
            hotKeys.append(hotKey)
        }
        active = true; error = nil
        displays?.refresh()
    }

    private func fail() {
        suspend()
        error = "⌃⌥↑/↓ est déjà utilisé ou refusé par macOS. Les curseurs restent disponibles."
    }

    func suspend() {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKeys.removeAll(); handler = nil; active = false
    }
}
