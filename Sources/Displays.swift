import AppKit
import Combine

struct DisplayReading: Identifiable, Sendable {
    enum Mode: Sendable { case apple, ddc, shade }
    let id: CGDirectDisplayID
    let name: String
    let isBuiltin: Bool
    var brightness: Double?
    var mode: Mode
}

actor BrightnessReader {
    func read(_ id: CGDirectDisplayID) -> (Double?, Int32) {
        var value = 0.0
        let mode = MPReadBrightness(id, &value)
        return (mode == 0 ? nil : value, mode)
    }

    func write(_ id: CGDirectDisplayID, value: Double, ddc: Bool) async -> Double? {
        guard MPWriteBrightness(id, value) else { return nil }
        try? await Task.sleep(for: .milliseconds(ddc ? 120 : 40))
        let (actual, _) = read(id)
        return actual
    }
}

@MainActor
final class DisplayController: ObservableObject {
    @Published private(set) var displays: [DisplayReading] = []
    @Published private(set) var busy = false
    @Published var error: String?
    private let reader = BrightnessReader()
    private var shades: [CGDirectDisplayID: SoftwareBrightness] = [:]
    private var refreshTask: Task<Void, Never>?
    private var pending: [CGDirectDisplayID: (DisplayReading, Double)] = [:]
    private var writing: Task<Void, Never>?

    func refresh() {
        guard !busy else { return }
        refreshTask?.cancel()
        let screens = NSScreen.screens.compactMap { screen -> DisplayReading? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = number.uint32Value
            let builtin = CGDisplayIsBuiltin(id) != 0
            let name = screen.localizedName.isEmpty ? (builtin ? "Écran intégré" : "Écran externe") : screen.localizedName
            return DisplayReading(id: id, name: name, isBuiltin: builtin,
                                  brightness: nil, mode: .apple)
        }
        let online = Set(screens.map(\.id))
        for id in Array(shades.keys) where !online.contains(id) { shades.removeValue(forKey: id)?.restore() }
        refreshTask = Task { [weak self, reader] in
            var results: [DisplayReading] = []
            for var screen in screens {
                let (value, backend) = await reader.read(screen.id)
                guard !Task.isCancelled else { return }
                screen.brightness = value
                screen.mode = backend == 2 ? .ddc : .apple
                if backend == 0 && !screen.isBuiltin {
                    screen.mode = .shade
                    screen.brightness = GammaTable.read(screen.id) == nil ? nil : self?.shades[screen.id]?.level ?? 1
                }
                results.append(screen)
            }
            self?.displays = results
        }
    }

    func stopReading() { refreshTask?.cancel(); refreshTask = nil }

    func set(_ display: DisplayReading, to value: Double) {
        guard value.isFinite, (0...1).contains(value),
            NSScreen.screens.contains(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id
            }) else { return }
        refreshTask?.cancel()
        if display.mode == .shade {
            let level = min(1, max(0.2, value))
            if level >= 0.999 { shades.removeValue(forKey: display.id)?.restore() }
            else {
                guard let dimming = shades[display.id] ?? SoftwareBrightness(display.id), dimming.set(level) else {
                    error = "macOS a refusé l’atténuation de cet écran."
                    return
                }
                shades[display.id] = dimming
            }
            if let index = displays.firstIndex(where: { $0.id == display.id }) { displays[index].brightness = level }
            error = nil
            return
        }
        // Keep only the latest position per display while hardware is answering.
        // Sliders stay enabled; intermediate mouse events never create an I2C backlog.
        pending[display.id] = (display, value)
        guard writing == nil else { return }
        busy = true
        writing = Task { [weak self] in
            guard let self else { return }
            defer { busy = false; writing = nil }
            while let (id, request) = pending.first {
                pending.removeValue(forKey: id)
                let (display, value) = request
                let actual = await reader.write(id, value: value, ddc: display.mode == .ddc)
                guard !Task.isCancelled else { return }
                guard pending[id] == nil else { continue }
                if let actual, let index = displays.firstIndex(where: { $0.id == id }) { displays[index].brightness = actual }
                if let actual, abs(actual - value) < 0.03 { error = nil }
                else { error = "L’écran n’a pas confirmé ce niveau de luminosité. Actualise ou vérifie DDC/CI dans le menu de l’écran." }
            }
        }
    }

    func clearShades() {
        for dimming in shades.values { dimming.restore() }
        shades.removeAll()
    }

    func stop() {
        stopReading()
        writing?.cancel(); writing = nil; pending.removeAll()
        clearShades()
    }
}

struct GammaTable {
    let red: [CGGammaValue]
    let green: [CGGammaValue]
    let blue: [CGGammaValue]

    static func read(_ display: CGDirectDisplayID) -> GammaTable? {
        let capacity = CGDisplayGammaTableCapacity(display)
        guard capacity > 0, capacity <= 4096 else { return nil }
        var r = [CGGammaValue](repeating: 0, count: Int(capacity)), g = r, b = r
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, capacity, &r, &g, &b, &count) == .success,
            count > 0, count <= capacity else { return nil }
        return GammaTable(red: Array(r.prefix(Int(count))), green: Array(g.prefix(Int(count))), blue: Array(b.prefix(Int(count))))
    }

    func scaled(_ level: Double) -> GammaTable {
        GammaTable(red: red.map { $0 * Float(level) }, green: green.map { $0 * Float(level) }, blue: blue.map { $0 * Float(level) })
    }

    func apply(_ display: CGDirectDisplayID) -> Bool {
        guard !red.isEmpty, red.count <= 4096, red.count == green.count, red.count == blue.count,
            (red + green + blue).allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return false }
        return CGSetDisplayTransferByTable(display, UInt32(red.count), red, green, blue) == .success
    }

    func matches(_ other: GammaTable) -> Bool {
        guard red.count == other.red.count, green.count == other.green.count, blue.count == other.blue.count else { return false }
        for (left, right) in [(red, other.red), (green, other.green), (blue, other.blue)] {
            for index in left.indices {
                let difference = abs(left[index] - right[index])
                if !difference.isFinite || difference >= 0.002 { return false }
            }
        }
        return true
    }
}

@MainActor
private final class SoftwareBrightness {
    let display: CGDirectDisplayID
    private var original: GammaTable
    private var applied: GammaTable?
    private(set) var level = 1.0

    init?(_ display: CGDirectDisplayID) {
        guard let table = GammaTable.read(display) else { return nil }
        self.display = display; original = table
    }

    func set(_ level: Double) -> Bool {
        guard let current = GammaTable.read(display) else { return false }
        // Respect a subsequent change made by Night Shift, ColorSync or another app.
        if let applied, !current.matches(applied) { original = current }
        let table = original.scaled(level)
        guard table.apply(display) else { return false }
        applied = table; self.level = level
        return true
    }

    func restore() {
        guard let applied, let current = GammaTable.read(display), current.matches(applied) else { return }
        _ = original.apply(display)
    }
}
