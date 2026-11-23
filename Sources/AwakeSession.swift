import Combine
import Foundation
import IOKit.pwr_mgt

@MainActor
final class AwakeSession: ObservableObject {
    @Published private(set) var deadline: Date?
    private var assertions: [IOPMAssertionID] = []
    private var expiration: Timer?

    func start(minutes: Int) throws {
        guard [15, 30, 60].contains(minutes) else {
            throw NSError(domain: "MacPanel.Awake", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Choisis 15, 30 ou 60 minutes."])
        }
        stop()
        let timeout = Double(minutes * 60)
        for type in [kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionTypePreventUserIdleDisplaySleep] {
            var identifier = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithDescription(type as CFString, "MacPanel — maintien temporaire" as CFString,
                nil, nil, nil, timeout, kIOPMAssertionTimeoutActionRelease as CFString, &identifier)
            guard result == kIOReturnSuccess else {
                stop()
                throw NSError(domain: "MacPanel.Awake", code: Int(result),
                    userInfo: [NSLocalizedDescriptionKey: "macOS a refusé le maintien éveillé."])
            }
            assertions.append(identifier)
        }
        deadline = Date().addingTimeInterval(timeout)
        expiration = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }

    func stop() {
        expiration?.invalidate()
        expiration = nil
        for identifier in assertions { IOPMAssertionRelease(identifier) }
        assertions.removeAll()
        deadline = nil
    }
}
