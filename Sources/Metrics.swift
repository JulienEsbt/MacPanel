import Foundation

struct CPUTicks: Sendable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    func utilization(since previous: CPUTicks?) -> Double? {
        guard let previous else { return nil }
        // Mach exposes wrapping 32-bit counters, including on long-running Macs.
        let busy = UInt64(user &- previous.user) + UInt64(system &- previous.system)
            + UInt64(nice &- previous.nice)
        let total = busy + UInt64(idle &- previous.idle)
        guard total > 0 else { return nil }
        return 100 * Double(busy) / Double(total)
    }
}

enum MetricsMath {
    static func networkRate(current: UInt64, previous: UInt64, seconds: Double) -> Double? {
        guard seconds.isFinite, seconds > 0, current >= previous else { return nil }
        return Double(current - previous) / seconds
    }
    static func percentage(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...100).contains(value) else { return nil }
        return value
    }

    static func memoryUsed(active: UInt64, inactive: UInt64, wired: UInt64,
                           compressed: UInt64, purgeable: UInt64, external: UInt64,
                           pageSize: UInt64, physical: UInt64) -> UInt64? {
        guard pageSize > 0, physical > 0 else { return nil }
        let pages = Double(active) + Double(inactive) + Double(wired) + Double(compressed)
            - Double(purgeable) - Double(external)
        guard pages >= 0 else { return nil }
        let bytes = pages * Double(pageSize)
        if bytes >= Double(physical) { return physical }
        return UInt64(bytes)
    }
}

enum MemoryPressure: String, Sendable {
    case normal, warning, critical

    init?(systemValue: Int32) {
        switch systemValue {
        case 1: self = .normal
        case 2: self = .warning
        case 4: self = .critical
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .normal: "Normale"
        case .warning: "Élevée"
        case .critical: "Critique"
        }
    }
}
