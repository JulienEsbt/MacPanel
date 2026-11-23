import XCTest

final class TelemetryTests: XCTestCase {
    func testNetworkRateUsesElapsedTimeAndRejectsResetOrInvalidTime() throws {
        XCTAssertEqual(try XCTUnwrap(MetricsMath.networkRate(current: 900, previous: 100, seconds: 2)), 400)
        XCTAssertEqual(MetricsMath.networkRate(current: 100, previous: 100, seconds: 2), 0)
        XCTAssertNil(MetricsMath.networkRate(current: 50, previous: 100, seconds: 2))
        for seconds in [0, -1, .nan, .infinity] {
            XCTAssertNil(MetricsMath.networkRate(current: 900, previous: 100, seconds: seconds))
        }
    }

    func testMemoryPressureUsesKernelLevelsNotPercentageOfRAM() {
        XCTAssertEqual(MemoryPressure(systemValue: 1), .normal)
        XCTAssertEqual(MemoryPressure(systemValue: 2), .warning)
        XCTAssertEqual(MemoryPressure(systemValue: 4), .critical)
        XCTAssertNil(MemoryPressure(systemValue: 0))
        XCTAssertNil(MemoryPressure(systemValue: 99))
    }
}
