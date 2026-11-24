import Combine
import Foundation

enum PanelSection: String, CaseIterable, Identifiable {
    case metrics, telemetry, apps, commands, awake
    var id: String { rawValue }
    var title: String {
        switch self {
        case .metrics: "CPU, RAM et GPU"
        case .telemetry: "Pression mémoire et réseau"
        case .apps: "Applications gourmandes"
        case .commands: "Commandes rapides"
        case .awake: "Maintien éveillé"
        }
    }
}

@MainActor
final class PanelPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published private(set) var sections: [PanelSection]
    @Published private(set) var commandOrder: [QuickSwitch]
    @Published private var hidden: Set<String>
    @Published private var hiddenCommands: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sections = Self.ordered(defaults.stringArray(forKey: "panelSections"), all: PanelSection.allCases)
        commandOrder = Self.ordered(defaults.stringArray(forKey: "panelCommands"), all: QuickSwitch.allCases)
        hidden = Set(defaults.stringArray(forKey: "panelHiddenSections") ?? [])
        hiddenCommands = Set(defaults.stringArray(forKey: "panelHiddenCommands") ?? [])
    }

    private static func ordered<T: RawRepresentable & Equatable>(_ ids: [String]?, all: [T]) -> [T] where T.RawValue == String {
        var result: [T] = []
        for id in ids ?? [] {
            if let item = all.first(where: { $0.rawValue == id }), !result.contains(item) { result.append(item) }
        }
        return result + all.filter { !result.contains($0) }
    }

    var visibleSections: [PanelSection] { sections.filter { isVisible($0) } }
    var visibleCommands: [QuickSwitch] { commandOrder.filter { !hiddenCommands.contains($0.rawValue) } }
    func isVisible(_ section: PanelSection) -> Bool { !hidden.contains(section.rawValue) }
    func setVisible(_ section: PanelSection, _ value: Bool) {
        if value { hidden.remove(section.rawValue) } else { hidden.insert(section.rawValue) }
        defaults.set(Array(hidden), forKey: "panelHiddenSections")
    }
    func setCommandVisible(_ command: QuickSwitch, _ value: Bool) {
        if value { hiddenCommands.remove(command.rawValue) } else { hiddenCommands.insert(command.rawValue) }
        defaults.set(Array(hiddenCommands), forKey: "panelHiddenCommands")
    }
    func move(_ section: PanelSection, by offset: Int) {
        guard let index = sections.firstIndex(of: section), sections.indices.contains(index + offset) else { return }
        sections.swapAt(index, index + offset)
        defaults.set(sections.map(\.rawValue), forKey: "panelSections")
    }
    func moveCommand(_ command: QuickSwitch, by offset: Int) {
        guard let index = commandOrder.firstIndex(of: command), commandOrder.indices.contains(index + offset) else { return }
        commandOrder.swapAt(index, index + offset)
        defaults.set(commandOrder.map(\.rawValue), forKey: "panelCommands")
    }
    func reset() {
        sections = PanelSection.allCases; commandOrder = QuickSwitch.allCases
        hidden = []; hiddenCommands = []
        for key in ["panelSections", "panelCommands", "panelHiddenSections", "panelHiddenCommands"] { defaults.removeObject(forKey: key) }
    }
}
