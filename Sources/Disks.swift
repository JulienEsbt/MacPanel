import AppKit
import Combine
import Foundation

struct DiskVolume: Identifiable, Sendable {
    let url: URL
    let uuid: String?
    let name: String
    let total: Int64?
    let available: Int64?
    let isInternal: Bool?
    let isEjectable: Bool
    var id: String { url.path }
    var canEject: Bool { isInternal == false && isEjectable && url.path != "/" && uuid?.isEmpty == false }
    var used: Int64? {
        guard let total, total > 0, let available, available >= 0 else { return nil }
        return total - min(total, available)
    }
    var usedFraction: Double? {
        guard let total, let used else { return nil }
        return Double(used) / Double(total)
    }
}

actor DiskReader {
    private let listOverride: (@Sendable () -> [DiskVolume])?
    private let ejectOverride: (@Sendable (DiskVolume) throws -> Void)?

    init(listOverride: (@Sendable () -> [DiskVolume])? = nil, ejectOverride: (@Sendable (DiskVolume) throws -> Void)? = nil) {
        self.listOverride = listOverride; self.ejectOverride = ejectOverride
    }

    func eject(_ disk: DiskVolume) throws {
        guard let current = volumes().first(where: { $0.id == disk.id }),
            current.canEject, current.uuid == disk.uuid else {
            throw NSError(domain: "MacPanel.Disks", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Ce volume n’est plus disponible."])
        }
        // NSWorkspace's ejection API is synchronous: keep it off the UI actor.
        if let ejectOverride { try ejectOverride(current) }
        else { try NSWorkspace.shared.unmountAndEjectDevice(at: current.url) }
    }

    func ejectAll(_ targets: [DiskVolume]) -> [String] {
        var failures: [String] = []
        for target in targets where target.canEject {
            // A previous ejection can remove several volumes on the same device.
            guard volumes().contains(where: { $0.id == target.id }) else { continue }
            do { try eject(target) }
            catch { failures.append("\(target.name) : \(error.localizedDescription)") }
        }
        return failures
    }

    func volumes() -> [DiskVolume] {
        if let listOverride { return listOverride() }
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeUUIDStringKey, .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsInternalKey, .volumeIsEjectableKey, .volumeIsBrowsableKey]
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []
        var seen = Set<String>()
        let volumes = ([root] + mounted).compactMap { url -> DiskVolume? in
            guard seen.insert(url.standardizedFileURL.path).inserted,
                let info = try? url.resourceValues(forKeys: keys),
                url.path == "/" || info.volumeIsBrowsable != false else { return nil }
            let total = info.volumeTotalCapacity.map(Int64.init)
            // Use the same filesystem free-space counter for used + free = total.
            // The "important usage" API includes purgeable data and would understate used storage.
            let available = info.volumeAvailableCapacity.map(Int64.init)
            return DiskVolume(url: url, uuid: info.volumeUUIDString, name: info.volumeName ?? url.lastPathComponent,
                total: total.flatMap { $0 > 0 ? $0 : nil },
                available: available.flatMap { $0 >= 0 ? $0 : nil },
                isInternal: info.volumeIsInternal, isEjectable: info.volumeIsEjectable == true)
        }
        return volumes.sorted {
            if ($0.url.path == "/") != ($1.url.path == "/") { return $0.url.path == "/" }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

@MainActor
final class DiskController: ObservableObject {
    @Published private(set) var volumes: [DiskVolume] = []
    @Published private(set) var ejecting: String?
    @Published var error: String?
    @Published private(set) var notice: String?
    private let reader = DiskReader()
    private var polling: Task<Void, Never>?

    func start() {
        guard polling == nil else { return }
        polling = Task { [weak self, reader] in
            while !Task.isCancelled {
                let volumes = await reader.volumes()
                guard !Task.isCancelled else { break }
                self?.volumes = volumes
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stop() { polling?.cancel(); polling = nil }

    func open(_ disk: DiskVolume) { NSWorkspace.shared.open(disk.url) }

    func eject(_ disk: DiskVolume) {
        guard disk.canEject, ejecting == nil else { return }
        ejecting = disk.id
        notice = nil
        Task {
            defer { ejecting = nil }
            // Refresh identity before acting on a path which might have been reused.
            guard let current = await reader.volumes().first(where: { $0.id == disk.id }),
                current.canEject, current.uuid == disk.uuid else {
                error = "Ce volume n’est plus disponible. Réessaie après actualisation."
                return
            }
            do {
                try await reader.eject(current)
                volumes = await reader.volumes()
                error = nil
            } catch { self.error = "Éjection refusée : \(error.localizedDescription)" }
        }
    }

    func ejectAll() {
        let targets = volumes.filter(\.canEject)
        guard ejecting == nil, !targets.isEmpty else { return }
        ejecting = "all"; error = nil; notice = nil
        Task {
            defer { ejecting = nil }
            let failures = await reader.ejectAll(targets)
            volumes = await reader.volumes()
            if failures.isEmpty { notice = "Éjection terminée. Tu peux débrancher les disques éjectés." }
            else { error = "Éjection incomplète — \(failures.joined(separator: " · "))" }
        }
    }
}
