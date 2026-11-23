import Combine
import CoreAudio
import Foundation

enum QuickSwitch: String, CaseIterable, Identifiable {
    case darkMode, desktopHidden, dockHidden, menuBarHidden, muted
    var id: String { rawValue }

    var title: String {
        switch self {
        case .darkMode: "Mode sombre"
        case .desktopHidden: "Masquer les icônes du bureau"
        case .dockHidden: "Masquer automatiquement le Dock"
        case .menuBarHidden: "Masquer automatiquement la barre"
        case .muted: "Couper le son"
        }
    }

    var symbol: String {
        switch self {
        case .darkMode: "moon"
        case .desktopHidden: "desktopcomputer"
        case .dockHidden: "dock.rectangle"
        case .menuBarHidden: "menubar.rectangle"
        case .muted: "speaker.slash"
        }
    }

    var help: String {
        switch self {
        case .darkMode: "Change l’apparence du système. macOS demandera une autorisation d’automatisation au premier changement."
        case .desktopHidden: "Les fichiers restent sur le bureau. Le Finder sera relancé pour actualiser leur affichage."
        case .dockHidden: "Le Dock réapparaît au passage du pointeur. Cette commande relance le Dock."
        case .menuBarHidden: "La barre réapparaît au bord supérieur. Cette commande relance les éléments système de la barre."
        case .muted: "Agit sur la sortie audio actuellement choisie. Certaines sorties externes ne permettent pas cette commande."
        }
    }
}

struct ControlFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

actor SystemPreferences {
    // All programs, preference keys and AppleScript fragments are fixed by this app.
    // No shell, downloaded script, or user-supplied command is executed.
    private func run(_ executable: String, _ arguments: [String]) throws -> (Int32, String, String) {
        let process = Process()
        let output = Pipe(), errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        process.environment = environment
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
        defer { timeout.cancel() }
        process.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let error = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (process.terminationStatus, text.trimmingCharacters(in: .whitespacesAndNewlines), error)
    }

    private func preference(_ domain: String, _ key: String) throws -> String? {
        let (status, text, error) = try run("/usr/bin/defaults", ["read", domain, key])
        if status == 0 { return text }
        // macOS 27 uses a different diagnostic for an unset preference.
        // In light mode AppleInterfaceStyle is removed rather than set to Light.
        if error.contains("does not exist") || error.contains("Could not find key '") { return nil }
        throw ControlFailure(message: "Impossible de lire le réglage système. Réessaie après avoir fermé les Réglages système.")
    }

    private func boolean(_ domain: String, _ key: String, default fallback: Bool) throws -> Bool {
        guard let value = try preference(domain, key) else { return fallback }
        switch value.lowercased() {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: throw ControlFailure(message: "Ce réglage utilise un format non pris en charge sur cette version de macOS.")
        }
    }

    func read() throws -> [QuickSwitch: Bool] {
        var values: [QuickSwitch: Bool] = [
            .darkMode: try preference("NSGlobalDomain", "AppleInterfaceStyle")?.lowercased() == "dark",
            .desktopHidden: try !boolean("com.apple.finder", "CreateDesktop", default: true),
            .dockHidden: try boolean("com.apple.dock", "autohide", default: false),
            .menuBarHidden: try boolean("NSGlobalDomain", "_HIHideMenuBar", default: false)
        ]
        if let audio = try? audioMute() { values[.muted] = audio }
        return values
    }

    func set(_ control: QuickSwitch, to enabled: Bool) throws {
        if control == .muted { try setAudioMute(enabled); return }
        if control == .darkMode {
            let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(enabled ? "true" : "false")"
            let (status, _, error) = try run("/usr/bin/osascript", ["-e", script])
            guard status == 0 else {
                if error.contains("1743") || error.lowercased().contains("not authorized") {
                    throw ControlFailure(message: "Autorise MacPanel à piloter Événements système dans Réglages système → Confidentialité et sécurité → Automatisation.")
                }
                throw ControlFailure(message: "Le changement d’apparence a échoué ou a été annulé. Aucune autorisation ne sera redemandée automatiquement.")
            }
            return
        }
        let domain: String, key: String, value: Bool, reload: String
        switch control {
        case .desktopHidden: (domain, key, value, reload) = ("com.apple.finder", "CreateDesktop", !enabled, "Finder")
        case .dockHidden: (domain, key, value, reload) = ("com.apple.dock", "autohide", enabled, "Dock")
        case .menuBarHidden: (domain, key, value, reload) = ("NSGlobalDomain", "_HIHideMenuBar", enabled, "SystemUIServer")
        case .darkMode, .muted: return
        }
        let (status, _, _) = try run("/usr/bin/defaults", ["write", domain, key, "-bool", value ? "true" : "false"])
        guard status == 0 else { throw ControlFailure(message: "macOS a refusé la modification de ce réglage.") }
        let (reloadStatus, _, _) = try run("/usr/bin/killall", [reload])
        guard reloadStatus == 0 else {
            throw ControlFailure(message: "Le réglage est enregistré, mais son affichage n’a pas pu être actualisé. Reconnecte ta session pour l’appliquer.")
        }
    }

    private func outputDevice() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { throw ControlFailure(message: "Aucune sortie audio disponible.") }
        return device
    }

    private func audioMute() throws -> Bool {
        let device = try outputDevice()
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0, size = UInt32(MemoryLayout<UInt32>.size)
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue,
              AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            throw ControlFailure(message: "Cette sortie audio ne permet pas la commande Muet.")
        }
        return value != 0
    }

    private func setAudioMute(_ enabled: Bool) throws {
        let device = try outputDevice()
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = enabled ? 1 : 0
        guard AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr else {
            throw ControlFailure(message: "Cette sortie audio a refusé la commande Muet.")
        }
    }
}

@MainActor
final class SystemControls: ObservableObject {
    @Published private(set) var values: [QuickSwitch: Bool] = [:]
    @Published private(set) var busy = false
    @Published var error: String?
    private let preferences = SystemPreferences()

    func refresh() {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { values = try await preferences.read(); error = nil }
            catch { self.error = error.localizedDescription }
        }
    }

    func set(_ control: QuickSwitch, to enabled: Bool) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await preferences.set(control, to: enabled)
                // Allow macOS a brief turn to publish changed preferences.
                try await Task.sleep(for: .milliseconds(200))
                values = try await preferences.read()
                guard values[control] == enabled else {
                    throw ControlFailure(message: "macOS n’a pas confirmé le changement. Le réglage réel reste affiché.")
                }
                error = nil
            } catch { self.error = error.localizedDescription }
        }
    }
}
