import XCTest

final class DiskTests: XCTestCase {
    func testInternalAndUnknownVolumesCannotBeEjected() {
        for internalState: Bool? in [true, nil] {
            let disk = disk(internalState: internalState, ejectable: true)
            XCTAssertFalse(disk.canEject)
        }
        XCTAssertTrue(disk(internalState: false, ejectable: true).canEject)
        XCTAssertFalse(disk(internalState: false, ejectable: false).canEject)
    }

    func testPurgeableSpaceCannotProduceNegativeUsage() {
        XCTAssertEqual(disk(internalState: true, ejectable: false, free: 120).usedFraction, 0)
        XCTAssertEqual(disk(internalState: true, ejectable: false, free: 25).usedFraction, 0.75)
        XCTAssertNil(disk(internalState: true, ejectable: false, free: -1).usedFraction)
    }

    func testActualVolumesIncludeRootAndAreNotDuplicated() async throws {
        let volumes = await DiskReader().volumes()
        XCTAssertEqual(volumes.filter { $0.url.path == "/" }.count, 1)
        XCTAssertEqual(Set(volumes.map(\.id)).count, volumes.count)
        XCTAssertFalse(try XCTUnwrap(volumes.first { $0.url.path == "/" }).canEject)
    }

    private func disk(internalState: Bool?, ejectable: Bool, free: Int64 = 25) -> DiskVolume {
        DiskVolume(url: URL(fileURLWithPath: "/Volumes/Test"), uuid: "test", name: "Test",
                   total: 100, available: free, isInternal: internalState, isEjectable: ejectable)
    }
}
