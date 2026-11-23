import Combine
import Darwin
import Foundation
import IOKit

struct SystemSnapshot: Sendable, Equatable {
    var cpu: Double?
    var gpu: Double?
    var memoryUsed: UInt64?
    var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    var sampledAt: Date?
    var memoryPressure: MemoryPressure?
    var download: Double?
    var upload: Double?
}

actor HardwareReader {
    private var previousCPU: CPUTicks?
    private var previousNetwork: [String: NetworkCounter] = [:]
    private var previousNetworkTime: TimeInterval?

    func reset() {
        previousCPU = nil
        previousNetwork = [:]
        previousNetworkTime = nil
    }

    func sample() -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        var load = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: load) / MemoryLayout<integer_t>.size)
        let cpuResult = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        if cpuResult == KERN_SUCCESS {
            let ticks = CPUTicks(user: load.cpu_ticks.0, system: load.cpu_ticks.1,
                                 idle: load.cpu_ticks.2, nice: load.cpu_ticks.3)
            snapshot.cpu = ticks.utilization(since: previousCPU)
            previousCPU = ticks
        } else {
            previousCPU = nil
        }

        var memory = vm_statistics64_data_t()
        var memoryCount = mach_msg_type_number_t(MemoryLayout.size(ofValue: memory) / MemoryLayout<integer_t>.size)
        let memoryResult = withUnsafeMutablePointer(to: &memory) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(memoryCount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &memoryCount)
            }
        }
        var pageSize: vm_size_t = 0
        if memoryResult == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS {
            snapshot.memoryUsed = MetricsMath.memoryUsed(active: UInt64(memory.active_count),
                inactive: UInt64(memory.inactive_count), wired: UInt64(memory.wire_count),
                compressed: UInt64(memory.compressor_page_count), purgeable: UInt64(memory.purgeable_count),
                external: UInt64(memory.external_page_count), pageSize: UInt64(pageSize), physical: snapshot.memoryTotal)
        }
        snapshot.gpu = gpuUtilization()
        var pressure: Int32 = 0
        var pressureSize = MemoryLayout.size(ofValue: pressure)
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &pressureSize, nil, 0) == 0 {
            snapshot.memoryPressure = MemoryPressure(systemValue: pressure)
        }
        let now = ProcessInfo.processInfo.systemUptime
        let network = networkCounters()
        if let previousNetworkTime, let network {
            var down: Double = 0, up: Double = 0, matches = 0
            for (name, counter) in network {
                guard let previous = previousNetwork[name],
                    let received = MetricsMath.networkRate(current: counter.received, previous: previous.received, seconds: now - previousNetworkTime),
                    let sent = MetricsMath.networkRate(current: counter.sent, previous: previous.sent, seconds: now - previousNetworkTime) else { continue }
                down += received; up += sent; matches += 1
            }
            if matches > 0 { snapshot.download = down; snapshot.upload = up }
        }
        previousNetwork = network ?? [:]
        previousNetworkTime = now
        snapshot.sampledAt = Date()
        return snapshot
    }

    private struct NetworkCounter { let received: UInt64; let sent: UInt64 }

    private func networkCounters() -> [String: NetworkCounter]? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(first) }
        var counters: [String: NetworkCounter] = [:]
        var item: UnsafeMutablePointer<ifaddrs>? = first
        while let current = item {
            defer { item = current.pointee.ifa_next }
            let interface = current.pointee
            guard let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                interface.ifa_flags & UInt32(IFF_UP | IFF_RUNNING) == UInt32(IFF_UP | IFF_RUNNING),
                let data = interface.ifa_data else { continue }
            let name = String(cString: interface.ifa_name)
            // Count physical Ethernet/Wi-Fi once; exclude utun, awdl, loopback and bridges.
            guard name.hasPrefix("en") else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            counters[name] = NetworkCounter(received: UInt64(stats.ifi_ibytes), sent: UInt64(stats.ifi_obytes))
        }
        return counters
    }

    private func gpuUtilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var readings: [Double] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let property = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString,
                kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
                let number = property["Device Utilization %"] as? NSNumber,
                CFGetTypeID(number) != CFBooleanGetTypeID(),
                let value = MetricsMath.percentage(number.doubleValue) else { continue }
            readings.append(value)
        }
        return readings.max()
    }
}

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot()
    private let reader = HardwareReader()
    private var polling: Task<Void, Never>?

    func start() {
        guard polling == nil else { return }
        polling = Task { [weak self, reader] in
            await reader.reset()
            while !Task.isCancelled {
                let sample = await reader.sample()
                guard !Task.isCancelled else { break }
                self?.snapshot = sample
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stop() {
        polling?.cancel()
        polling = nil
    }
}
