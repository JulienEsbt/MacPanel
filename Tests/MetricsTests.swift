import XCTest

final class MetricsTests: XCTestCase {
    func testCPURequiresTwoSamples() {
        XCTAssertNil(CPUTicks(user: 1, system: 1, idle: 8, nice: 0).utilization(since: nil))
    }

    func testCPUReportsBusyFractionAcrossAllCores() throws {
        let before = CPUTicks(user: 100, system: 50, idle: 500, nice: 0)
        let after = CPUTicks(user: 120, system: 60, idle: 570, nice: 0)
        XCTAssertEqual(try XCTUnwrap(after.utilization(since: before)), 30, accuracy: 0.001)
    }

    func testCPUCounterWrapDoesNotProduceNegativeOrHugeLoad() throws {
        let before = CPUTicks(user: .max - 1, system: 0, idle: 10, nice: 0)
        let after = CPUTicks(user: 1, system: 0, idle: 17, nice: 0)
        XCTAssertEqual(try XCTUnwrap(after.utilization(since: before)), 30, accuracy: 0.001)
    }

    func testUnchangedCPUIsUnknownRatherThanFakeZero() {
        let sample = CPUTicks(user: 10, system: 10, idle: 80, nice: 0)
        XCTAssertNil(sample.utilization(since: sample))
    }

    func testValidIdleAndFullGPUReadingsArePreserved() {
        XCTAssertEqual(MetricsMath.percentage(0), 0)
        XCTAssertEqual(MetricsMath.percentage(100), 100)
        XCTAssertEqual(MetricsMath.percentage(42.5), 42.5)
    }

    func testMissingOrMalformedGPUIsNotReportedAsZero() {
        for value: Double? in [nil, .nan, .infinity, -1, 101] {
            XCTAssertNil(MetricsMath.percentage(value))
        }
    }

    func testMemorySubtractsFileCacheAndPurgeablePages() {
        XCTAssertEqual(MetricsMath.memoryUsed(active: 30, inactive: 20, wired: 10,
            compressed: 5, purgeable: 5, external: 20, pageSize: 1024, physical: 100_000), 40_960)
    }

    func testInconsistentMemorySnapshotIsUnavailable() {
        XCTAssertNil(MetricsMath.memoryUsed(active: 0, inactive: 0, wired: 0,
            compressed: 0, purgeable: 10, external: 20, pageSize: 1024, physical: 100_000))
    }

    func testMemoryNeverExceedsInstalledPhysicalMemory() {
        XCTAssertEqual(MetricsMath.memoryUsed(active: 100, inactive: 20, wired: 10,
            compressed: 5, purgeable: 0, external: 0, pageSize: 1024, physical: 100_000), 100_000)
    }
}
