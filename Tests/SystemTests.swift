import XCTest
import IOKit.pwr_mgt

final class SystemTests: XCTestCase {
    func testHardwareReaderReturnsBoundedRealMeasurements() async throws {
        let reader = HardwareReader()
        let first = await reader.sample()
        XCTAssertNil(first.cpu)
        XCTAssertGreaterThan(try XCTUnwrap(first.memoryUsed), 0)
        XCTAssertLessThanOrEqual(try XCTUnwrap(first.memoryUsed), first.memoryTotal)
        try await Task.sleep(for: .milliseconds(1200))
        let second = await reader.sample()
        XCTAssertTrue((0...100).contains(try XCTUnwrap(second.cpu)))
        if let gpu = second.gpu { XCTAssertTrue((0...100).contains(gpu)) }
    }

    @MainActor
    func testClosingPanelStopsPublishingMeasurements() async throws {
        let monitor = SystemMonitor()
        monitor.start()
        try await Task.sleep(for: .milliseconds(500))
        monitor.stop()
        let last = monitor.snapshot
        XCTAssertNotNil(last.sampledAt)
        try await Task.sleep(for: .milliseconds(2300))
        XCTAssertEqual(monitor.snapshot, last)
    }

    @MainActor
    func testAwakeSessionCreatesAndReleasesBothActualAssertions() async throws {
        let session = AwakeSession()
        defer { session.stop() }
        try session.start(minutes: 15)
        XCTAssertNotNil(session.deadline)
        XCTAssertEqual(try ownAssertions(), 2)
        // Replacing a session must not leave the first pair of assertions alive.
        try session.start(minutes: 30)
        XCTAssertEqual(try ownAssertions(), 2)
        session.stop()
        XCTAssertNil(session.deadline)
        XCTAssertEqual(try ownAssertions(), 0)
    }

    @MainActor
    func testUnsupportedAwakeDurationDoesNotCreateAnAssertion() async throws {
        let session = AwakeSession()
        for value in [-1, 0, 5, Int.max] {
            XCTAssertThrowsError(try session.start(minutes: value))
        }
        XCTAssertNil(session.deadline)
        XCTAssertEqual(try ownAssertions(), 0)
    }

    private func ownAssertions() throws -> Int {
        var result: Unmanaged<CFDictionary>?
        XCTAssertEqual(IOPMCopyAssertionsByProcess(&result), kIOReturnSuccess)
        let dictionary = try XCTUnwrap(result?.takeRetainedValue() as? [NSNumber: [[String: Any]]])
        return dictionary[NSNumber(value: ProcessInfo.processInfo.processIdentifier), default: []]
            .filter { ($0[kIOPMAssertionNameKey] as? String)?.hasPrefix("MacPanel —") == true }.count
    }
}
