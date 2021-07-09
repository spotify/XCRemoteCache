@testable import XCRemoteCache
import XCTest

class FilteredInvocationStorageTests: XCTestCase {

    let underlyingStorage = InMemoryInvocationStorage(command: "swiftc")
    var storage: FilteredInvocationStorage!

    override func setUp() {
        storage = FilteredInvocationStorage(storage: underlyingStorage, retrieveIgnoredCommands: ["to_ignore"])
    }

    func testStoresInvocations() throws {
        try storage.store(args: ["arg1"])

        XCTAssertEqual(try underlyingStorage.retrieveAll(), [["swiftc", "arg1"]])
    }

    func testRetrivesNonIgnoredInvocations() throws {
        try underlyingStorage.store(args: ["arg1"])

        let invocations = try storage.retrieveAll()

        XCTAssertEqual(invocations, [["swiftc", "arg1"]])
    }

    func testFiltersIgnoredInvocations() throws {
        storage = FilteredInvocationStorage(storage: underlyingStorage, retrieveIgnoredCommands: ["swiftc"])
        try underlyingStorage.store(args: ["arg1"])

        let invocations = try storage.retrieveAll()

        XCTAssertEqual(invocations, [])
    }

    func testThrowsWhenStorageIsCorrupted() throws {
        let corruptedStorage = CorruptedInMemoryInvocationStorage(command: "swiftc")
        try corruptedStorage.store(args: ["arg1"])
        storage = FilteredInvocationStorage(storage: corruptedStorage, retrieveIgnoredCommands: [])

        XCTAssertThrowsError(try storage.retrieveAll())
    }
}
