import AppKit
import Combine

struct DisplayReading: Identifiable, Sendable {
    enum Mode: Sendable { case apple, ddc, shade }
    let id: CGDirectDisplayID
    let name: String
    let isBuiltin: Bool
    var brightness: Double?
    var mode: Mode
    var volume: Double? = nil
}

actor BrightnessReader {
    private let readOverride: (@Sendable (CGDirectDisplayID) async -> (Double?, Int32))?

    init(readOverride: (@Sendable (CGDirectDisplayID) async -> (Double?, Int32))? = nil) {
        self.readOverride = readOverride
    }

    func read(_ id: CGDirectDisplayID) async -> (Double?, Int32) {
        if let readOverride { return await readOverride(id) }
        var value = 0.0
        let mode = MPReadBrightness(id, &value)
        return (mode == 0 ? nil : value, mode)
    }

    func write(_ id: CGDirectDisplayID, value: Double, ddc: Bool) async -> Double? {
        guard MPWriteBrightness(id, value) else { return nil }
        try? await Task.sleep(for: .milliseconds(ddc ? 120 : 40))
        let (actual, _) = await read(id)
        return actual
    }

    func readVolume(_ id: CGDirectDisplayID) -> Double? {
        var value = 0.0
        return MPReadDisplayVolume(id, &value) ? value : nil
    }
    func writeVolume(_ id: CGDirectDisplayID, value: Double) async -> Double? {
        guard MPWriteDisplayVolume(id, value) else { return nil }
        try? await Task.sleep(for: .milliseconds(120))
        return readVolume(id)
    }
}

enum BrightnessSync {
    static func fixedOffset(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        return (min(0.5, max(-0.5, value)) * 100).rounded() / 100
    }

    static func sourceLevel(changedLevel: Double, offset: Double, isBuiltin: Bool) -> Double? {
        guard changedLevel.isFinite, offset.isFinite, (0...1).contains(changedLevel) else { return nil }
        return min(1, max(0, changedLevel - (isBuiltin ? 0 : offset)))
    }

    static func range(offset: Double, software: Bool, linked: Bool) -> ClosedRange<Double> {
        let offset = offset.isFinite && linked ? min(0.5, max(-0.5, offset)) : 0
        return max(software ? 0.2 : 0, offset)...min(1, 1 + offset)
    }
    static func level(source: Double, offset: Double, software: Bool) -> Double? {
        guard source.isFinite, offset.isFinite, (0...1).contains(source) else { return nil }
        return min(1, max(software ? 0.2 : 0, source + min(0.5, max(-0.5, offset))))
    }
}

@MainActor
final class DisplayController: ObservableObject {
    @Published private(set) var displays: [DisplayReading] = []
    @Published private(set) var busy = false
    @Published var error: String?
    @Published private(set) var syncEnabled: Bool
    @Published private(set) var syncOffsets: [String: Double]
    private let defaults: UserDefaults
    private var synchronization: Task<Void, Never>?
    private var lastSource: Double?
    private let reader: BrightnessReader
    private var observation: Task<Void, Never>?
    private var revision: UInt64 = 0

    init(reader: BrightnessReader = BrightnessReader(), defaults: UserDefaults = .standard) {
        self.reader = reader; self.defaults = defaults
        syncEnabled = defaults.bool(forKey: "brightnessSyncEnabled")
        syncOffsets = (defaults.dictionary(forKey: "brightnessSyncOffsets") as? [String: Double] ?? [:])
            .filter { $0.value.isFinite && (-0.5...0.5).contains($0.value) }
    }
    private var shades: [CGDirectDisplayID: SoftwareBrightness] = [:]
    private var refreshTask: Task<Void, Never>?
    private var pending: [CGDirectDisplayID: (DisplayReading, Double)] = [:]
    private var writing: Task<Void, Never>?
    private var desiredBrightness: [CGDirectDisplayID: Double] = [:]
    private var pendingVolumes: [CGDirectDisplayID: Double] = [:]

    private func stableKey(_ display: DisplayReading) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(display.id)?.takeRetainedValue() else { return display.name }
        return CFUUIDCreateString(nil, uuid) as String
    }
    func offset(for display: DisplayReading) -> Double { syncOffsets[stableKey(display)] ?? 0 }
    func brightnessRange(for display: DisplayReading) -> ClosedRange<Double> {
        BrightnessSync.range(offset: offset(for: display), software: display.mode == .shade,
            linked: syncEnabled && !display.isBuiltin && displays.contains(where: { $0.isBuiltin && $0.brightness != nil }))
    }
    func setOffset(_ value: Double, for display: DisplayReading) {
        guard let value = BrightnessSync.fixedOffset(value) else { return }
        syncOffsets[stableKey(display)] = value
        defaults.set(syncOffsets, forKey: "brightnessSyncOffsets")
        if syncEnabled, let source = displays.first(where: \.isBuiltin)?.brightness,
           let level = BrightnessSync.level(source: source, offset: value, software: display.mode == .shade) {
            set(display, to: level, synchronized: true)
        }
    }
    func setSyncEnabled(_ enabled: Bool) {
        syncEnabled = enabled; defaults.set(enabled, forKey: "brightnessSyncEnabled")
        suspendSynchronization()
        if enabled { resumeSynchronization() }
    }
    func resumeSynchronization() {
        guard syncEnabled, synchronization == nil else { return }
        synchronization = Task { [weak self] in
            while !Task.isCancelled {
                await self?.syncFromBuiltin()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
    func suspendSynchronization() { synchronization?.cancel(); synchronization = nil; lastSource = nil }
    private func syncFromBuiltin() async {
        guard !busy, displays.contains(where: { !$0.isBuiltin && $0.brightness != nil }),
            let source = displays.first(where: { $0.isBuiltin && $0.brightness != nil }) else { return }
        let (level, _) = await reader.read(source.id)
        guard !Task.isCancelled, !busy, let level else { return }
        if let index = displays.firstIndex(where: { $0.id == source.id }) { displays[index].brightness = level }
        if lastSource.map({ abs($0 - level) < 0.01 }) == true { return }
        lastSource = level
        synchronizeExternals(from: level)
    }
    private func synchronizeExternals(from level: Double) {
        for display in displays where !display.isBuiltin && display.brightness != nil {
            guard let target = BrightnessSync.level(source: level, offset: offset(for: display), software: display.mode == .shade),
                abs((desiredBrightness[display.id] ?? display.brightness ?? target) - target) > 0.01 else { continue }
            set(display, to: target, synchronized: true)
        }
    }

    var hasKeyboardTarget: Bool {
        let online = Set(NSScreen.screens.compactMap {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        })
        return displays.contains { !$0.isBuiltin && $0.brightness != nil && online.contains($0.id) }
    }

    func adjustExternal(_ direction: Int) {
        if syncEnabled, let source = displays.first(where: { $0.isBuiltin && $0.brightness != nil }),
            let current = desiredBrightness[source.id] ?? source.brightness,
            let next = BrightnessStep.nextLevel(current, direction: direction, software: false) {
            set(source, to: next)
            return
        }
        for display in displays where !display.isBuiltin {
            guard let current = desiredBrightness[display.id] ?? display.brightness,
                let next = BrightnessStep.nextLevel(current, direction: direction, software: display.mode == .shade) else { continue }
            set(display, to: next)
        }
    }

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
            self?.lastSource = nil
            if self?.busy == false { self?.desiredBrightness.removeAll() }
            // Audio capability discovery is independent of brightness availability.
            for screen in screens where !screen.isBuiltin {
                let volume = await reader.readVolume(screen.id)
                guard !Task.isCancelled, let index = self?.displays.firstIndex(where: { $0.id == screen.id }) else { return }
                self?.displays[index].volume = volume
            }
        }
    }

    func startObserving() {
        guard observation == nil else { return }
        observation = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshLevels()
                do { try await Task.sleep(for: .milliseconds(350)) }
                catch { return }
            }
        }
    }

    private func refreshLevels() async {
        guard !busy else { return }
        let expectedRevision = revision
        for screen in displays where screen.mode != .shade {
            let (level, _) = await reader.read(screen.id)
            guard !Task.isCancelled, !busy, revision == expectedRevision else { return }
            guard let level, level.isFinite, (0...1).contains(level),
                let index = displays.firstIndex(where: { $0.id == screen.id }) else { continue }
            if displays[index].brightness != level { displays[index].brightness = level }
            desiredBrightness.removeValue(forKey: screen.id)
        }
    }

    func stopObserving() {
        observation?.cancel(); observation = nil
    }

    func stopReading() {
        refreshTask?.cancel(); refreshTask = nil
        stopObserving()
    }

    func set(_ display: DisplayReading, to requestedValue: Double, synchronized: Bool = false) {
        guard requestedValue.isFinite, (0...1).contains(requestedValue),
            NSScreen.screens.contains(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id
            }) else { return }
        let range = brightnessRange(for: display)
        let value = min(range.upperBound, max(range.lowerBound, requestedValue))
        refreshTask?.cancel()
        revision &+= 1
        desiredBrightness[display.id] = value
        if syncEnabled && !synchronized {
            if let source = displays.first(where: { $0.isBuiltin && $0.brightness != nil }),
               let level = BrightnessSync.sourceLevel(changedLevel: value, offset: offset(for: display), isBuiltin: display.isBuiltin) {
                lastSource = level
                if !display.isBuiltin { set(source, to: level, synchronized: true) }
                synchronizeExternals(from: level)
            }
        }
        if display.mode == .shade {
            let level = min(1, max(0.2, value))
            if level >= 0.999 { shades.removeValue(forKey: display.id)?.restore() }
            else {
                guard let dimming = shades[display.id] ?? SoftwareBrightness(display.id), dimming.set(level) else {
                    desiredBrightness.removeValue(forKey: display.id)
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
        drainWrites()
    }

    func setVolume(_ display: DisplayReading, to value: Double) {
        guard value.isFinite, (0...1).contains(value), !display.isBuiltin, display.volume != nil,
            CGDisplayIsOnline(display.id) != 0 else { return }
        pendingVolumes[display.id] = value
        drainWrites()
    }

    private func drainWrites() {
        guard writing == nil else { return }
        busy = true
        writing = Task { [weak self] in
            guard let self else { return }
            defer { busy = false; writing = nil }
            while !pending.isEmpty || !pendingVolumes.isEmpty {
                if let (id, value) = pendingVolumes.first {
                    pendingVolumes.removeValue(forKey: id)
                    let actual = await reader.writeVolume(id, value: value)
                    guard !Task.isCancelled else { return }
                    if pendingVolumes[id] != nil { continue }
                    if let actual, let index = displays.firstIndex(where: { $0.id == id }) {
                        displays[index].volume = actual
                        error = abs(actual - value) < 0.03 ? nil : "L’écran n’a pas confirmé ce volume."
                    } else { error = "Le réglage du volume de l’écran a échoué. Vérifie DDC/CI et la connexion." }
                    continue
                }
                guard let (id, request) = pending.first else { break }
                pending.removeValue(forKey: id)
                let (display, value) = request
                let actual = await reader.write(id, value: value, ddc: display.mode == .ddc)
                guard !Task.isCancelled else { return }
                guard pending[id] == nil else { continue }
                if let actual, let index = displays.firstIndex(where: { $0.id == id }) { displays[index].brightness = actual }
                if let actual, abs(actual - value) < 0.03 { error = nil }
                else { desiredBrightness.removeValue(forKey: id); error = "L’écran n’a pas confirmé ce niveau de luminosité. Actualise ou vérifie DDC/CI dans le menu de l’écran." }
            }
        }
    }

    func clearShades() {
        for dimming in shades.values { dimming.restore() }
        shades.removeAll()
        desiredBrightness.removeAll()
    }

    func stop() {
        suspendSynchronization()
        stopReading()
        writing?.cancel(); writing = nil; pending.removeAll(); pendingVolumes.removeAll()
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
