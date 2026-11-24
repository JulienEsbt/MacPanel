import XCTest

final class AppUsageTests: XCTestCase {
    func testCurrentProcessCountersAreReadableWithoutAdditionalPermissions() async throws {
        let reader = AppUsageReader()
        let app = AppIdentity(pid: ProcessInfo.processInfo.processIdentifier, name: "Test host")
        let first = await reader.sample(apps: [app])
        XCTAssertGreaterThan(try XCTUnwrap(first.first).memory, 0)
        XCTAssertNil(first.first?.cpu)
        let next = await reader.sample(apps: [app])
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(next.first?.cpu), 0)
    }

    func testChildCountersAreAttributedOnceAndPIDReuseNeverProducesASpike() {
        let app = AppIdentity(pid: 100, name: "Editor")
        let previous = [ProcessCounter(pid: 100, parent: 1, started: 1, cpu: 1_000_000_000, memory: 100),
                        ProcessCounter(pid: 101, parent: 100, started: 2, cpu: 2_000_000_000, memory: 200)]
        let next = [ProcessCounter(pid: 100, parent: 1, started: 1, cpu: 2_000_000_000, memory: 150),
                    ProcessCounter(pid: 101, parent: 100, started: 2, cpu: 3_000_000_000, memory: 250),
                    ProcessCounter(pid: 200, parent: 200, started: 3, cpu: 9_000_000_000, memory: 800)]
        let result = AppUsageMath.readings(apps: [app], current: next, previous: previous, seconds: 2)
        XCTAssertEqual(result.first?.cpu, 100)
        XCTAssertEqual(result.first?.memory, 400)
        let reused = [ProcessCounter(pid: 100, parent: 1, started: 9, cpu: 90_000_000_000, memory: 50)]
        XCTAssertNil(AppUsageMath.readings(apps: [app], current: reused, previous: previous, seconds: 2).first?.cpu)
        XCTAssertNil(AppUsageMath.readings(apps: [app], current: next, previous: [], seconds: 0).first?.cpu)
    }
}
