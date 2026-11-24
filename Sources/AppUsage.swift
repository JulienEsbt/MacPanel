import AppKit
import Combine

struct AppIdentity: Sendable { let pid: Int32; let name: String }
struct ProcessCounter: Sendable {
    let pid: Int32
    let parent: Int32
    let started: UInt64
    let cpu: UInt64
    let memory: UInt64
}
struct AppUsage: Identifiable, Sendable {
    let id: Int32
    let name: String
    let cpu: Double?
    let memory: UInt64
}

enum AppUsageMath {
    static func readings(apps: [AppIdentity], current: [ProcessCounter], previous: [ProcessCounter], seconds: Double) -> [AppUsage] {
        let counters = Dictionary(current.map { ($0.pid, $0) }, uniquingKeysWith: { _, last in last })
        let old = Dictionary(previous.map { ($0.pid, $0) }, uniquingKeysWith: { _, last in last })
        let roots = Set(apps.map(\.pid))
        var totals: [Int32: (cpu: Double, memory: UInt64, measured: Bool)] = [:]
        for process in current {
            var pid = process.pid
            var visited = Set<Int32>()
            while !roots.contains(pid), let parent = counters[pid]?.parent, parent > 1, visited.insert(pid).inserted { pid = parent }
            guard roots.contains(pid) else { continue }
            var total = totals[pid] ?? (0, 0, false)
            total.memory = total.memory.addingReportingOverflow(process.memory).overflow ? UInt64.max : total.memory + process.memory
            if seconds.isFinite, seconds > 0, let before = old[process.pid], before.started == process.started, process.cpu >= before.cpu {
                total.cpu += Double(process.cpu - before.cpu) / (seconds * 1_000_000_000) * 100
                total.measured = true
            }
            totals[pid] = total
        }
        return apps.compactMap { app in
            guard let total = totals[app.pid] else { return nil }
            return AppUsage(id: app.pid, name: app.name, cpu: total.measured ? total.cpu : nil, memory: total.memory)
        }
    }
}

actor AppUsageReader {
    private var previous: [ProcessCounter] = []
    private var sampledAt: TimeInterval?
    func reset() { previous = []; sampledAt = nil }
    func sample(apps: [AppIdentity]) -> [AppUsage] {
        let time = ProcessInfo.processInfo.systemUptime
        let current = MPProcessCounters().compactMap { value -> ProcessCounter? in
            guard let pid = value["pid"], let parent = value["parent"], let started = value["started"],
                let cpu = value["cpu"], let memory = value["memory"] else { return nil }
            return ProcessCounter(pid: pid.int32Value, parent: parent.int32Value, started: started.uint64Value,
                                  cpu: cpu.uint64Value, memory: memory.uint64Value)
        }
        let result = AppUsageMath.readings(apps: apps, current: current, previous: previous, seconds: sampledAt.map { time - $0 } ?? 0)
        previous = current; sampledAt = time
        return result
    }
}

@MainActor
final class AppUsageMonitor: ObservableObject {
    @Published private(set) var apps: [AppUsage] = []
    @Published private(set) var panelVisible = false
    private let reader = AppUsageReader()
    private var polling: Task<Void, Never>?
    func setPanelVisible(_ visible: Bool) {
        panelVisible = visible
        if !visible { stop() }
    }
    func start() {
        guard panelVisible, polling == nil else { return }
        polling = Task { [weak self, reader] in
            await reader.reset()
            while !Task.isCancelled {
                let identities = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isTerminated }
                    .map { AppIdentity(pid: $0.processIdentifier, name: $0.localizedName ?? "Application") }
                let readings = await reader.sample(apps: identities)
                guard !Task.isCancelled else { return }
                self?.apps = readings
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
    func stop() { polling?.cancel(); polling = nil; apps = [] }
    func openActivityMonitor() { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")) }
}
