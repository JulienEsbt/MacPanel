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
    var canEject: Bool { isInternal == false && isEjectable && url.path != "/" }
    var usedFraction: Double? {
        guard let total, total > 0, let available, available >= 0 else { return nil }
        return 1 - min(1, Double(available) / Double(total))
    }
}

actor DiskReader {
    func eject(_ disk: DiskVolume) throws {
        guard let current = volumes().first(where: { $0.id == disk.id }),
            current.canEject, current.uuid == disk.uuid else {
            throw NSError(domain: "MacPanel.Disks", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Ce volume n’est plus disponible."])
        }
        // NSWorkspace's ejection API is synchronous: keep it off the UI actor.
        try NSWorkspace.shared.unmountAndEjectDevice(at: current.url)
    }

    func volumes() -> [DiskVolume] {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeUUIDStringKey, .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsInternalKey, .volumeIsEjectableKey, .volumeIsBrowsableKey]
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []
        var seen = Set<String>()
        let volumes = ([root] + mounted).compactMap { url -> DiskVolume? in
            guard seen.insert(url.standardizedFileURL.path).inserted,
                let info = try? url.resourceValues(forKeys: keys),
                url.path == "/" || info.volumeIsBrowsable != false else { return nil }
            let total = info.volumeTotalCapacity.map(Int64.init)
            let available = info.volumeAvailableCapacityForImportantUsage ?? info.volumeAvailableCapacity.map(Int64.init)
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
}
