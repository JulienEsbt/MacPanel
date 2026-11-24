import Carbon
import Combine
import Foundation

@MainActor
final class PanelShortcut: ObservableObject {
    @Published private(set) var selection = 0
    @Published private(set) var error: String?
    var action: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    static let labels = ["Désactivé", "⌃⌥M", "⌃⌥⌘M", "⌃⇧M"]

    func start(action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, registeredHotKeyID(event, signature: 0x4D43504C) == 1 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<PanelShortcut>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in owner.action?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { error = "Le raccourci clavier n’a pas pu être initialisé."; return }
        UserDefaults.standard.register(defaults: ["panelShortcut": 1])
        configure(UserDefaults.standard.integer(forKey: "panelShortcut"))
    }

    func configure(_ choice: Int) {
        guard Self.labels.indices.contains(choice), handler != nil else { return }
        if choice == selection && hotKey != nil { return }
        var replacement: EventHotKeyRef?
        if choice != 0 {
            let modifiers: UInt32 = switch choice {
            case 2: UInt32(controlKey | optionKey | cmdKey)
            case 3: UInt32(controlKey | shiftKey)
            default: UInt32(controlKey | optionKey)
            }
            let id = EventHotKeyID(signature: 0x4D43504C, id: 1)
            guard let keyCode = Self.keyCodeForM() else {
                error = "La disposition actuelle du clavier ne permet pas de trouver la touche M."
                return
            }
            let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &replacement)
            guard status == noErr else {
                error = "Ce raccourci est déjà utilisé ou refusé par macOS. Choisis une autre combinaison."
                return
            }
        }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = replacement
        selection = choice
        UserDefaults.standard.set(choice, forKey: "panelShortcut")
        error = nil
    }

    // Resolve the letter in the active layout: ANSI's physical M is a comma on AZERTY.
    static func keyCodeForM() -> UInt32? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
            let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        for code: UInt16 in 0..<128 {
            var deadKey: UInt32 = 0, length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKey, 4, &length, &characters)
            if status == noErr && String(utf16CodeUnits: characters, count: length).lowercased() == "m" { return UInt32(code) }
        }
        return nil
    }

    func keyboardLayoutChanged() {
        let choice = selection
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        selection = 0
        configure(choice)
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil; handler = nil; action = nil
    }
}
