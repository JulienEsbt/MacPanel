import XCTest

final class DiskTests: XCTestCase {
    func testGroupEjectionSkipsInternalVolumesAndReportsFailuresWithoutForcing() async {
        let internalDisk = disk(internalState: true, ejectable: true)
        let externalDisk = disk(internalState: false, ejectable: true)
        let reader = DiskReader(listOverride: { [externalDisk] }, ejectOverride: { _ in
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Volume occupé"])
        })
        let failures = await reader.ejectAll([internalDisk, externalDisk])
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures[0].contains("Volume occupé"))
    }

    func testInternalAndUnknownVolumesCannotBeEjected() {
        for internalState: Bool? in [true, nil] {
            let disk = disk(internalState: internalState, ejectable: true)
            XCTAssertFalse(disk.canEject)
        }
        XCTAssertTrue(disk(internalState: false, ejectable: true).canEject)
        XCTAssertFalse(disk(internalState: false, ejectable: false).canEject)
        let unidentified = DiskVolume(url: URL(fileURLWithPath: "/Volumes/Test"), uuid: nil, name: "Test",
            total: 100, available: 25, isInternal: false, isEjectable: true)
        XCTAssertFalse(unidentified.canEject)
    }

    func testPurgeableSpaceCannotProduceNegativeUsage() {
        XCTAssertEqual(disk(internalState: true, ejectable: false, free: 120).usedFraction, 0)
        XCTAssertEqual(disk(internalState: true, ejectable: false, free: 25).usedFraction, 0.75)
        XCTAssertNil(disk(internalState: true, ejectable: false, free: -1).usedFraction)
    }

    func testUsedStorageIsConsistentWithFreeAndTotalCapacity() {
        XCTAssertEqual(disk(internalState: true, ejectable: false, free: 25).used, 75)
        XCTAssertEqual(disk(internalState: true, ejectable: false, free: 120).used, 0)
        XCTAssertNil(disk(internalState: true, ejectable: false, free: -1).used)
        let unavailable = DiskVolume(url: URL(fileURLWithPath: "/"), uuid: nil, name: "Test",
            total: nil, available: 25, isInternal: true, isEjectable: false)
        XCTAssertNil(unavailable.used)
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
