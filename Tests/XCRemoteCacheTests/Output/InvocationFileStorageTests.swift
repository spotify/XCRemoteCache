@testable import XCRemoteCache
import XCTest

class InvocationFileStorageTests: FileXCTestCase {
    private static let timeout = 5.0

    private let command = "swift"
    private var file: URL!
    private var storage: ExistingFileStorage!

    override func setUpWithError() throws {
        file = try prepareTempDir().appendingPathComponent("file.history")
        try fileManager.spt_createEmptyFile(file)
        storage = ExistingFileStorage(storageFile: file, command: command)
    }

    func testStoresInvocation() throws {
        try storage.store(args: ["arg1", "arg2"])

        let content = fileManager.contents(atPath: file.path)
        XCTAssertEqual(content, "swift\0arg1\0arg2\0\0\n".data(using: .utf8))
    }

    func testAppendsInvocations() throws {
        try storage.store(args: ["arg1"])
        try storage.store(args: ["arg2"])

        let content = fileManager.contents(atPath: file.path)
        XCTAssertEqual(content, "swift\0arg1\0\0\nswift\0arg2\0\0\n".data(using: .utf8))
    }

    func testRetrievesEmptyStorage() throws {
        let fetchedInvocations = try storage.retrieveAll()

        XCTAssertEqual(fetchedInvocations, [])
    }

    func testRetrievesPreviousInvocations() throws {
        try storage.store(args: ["arg1"])
        try storage.store(args: ["arg2"])

        let fetchedInvocations = try storage.retrieveAll()

        XCTAssertEqual(fetchedInvocations, [[command, "arg1"], [command, "arg2"]])
    }

    func testRetrieveDeletesTheStorage() throws {
        try storage.store(args: ["arg1"])

        _ = try storage.retrieveAll()

        XCTAssertFalse(fileManager.fileExists(atPath: file.path))
    }

    func testRetrieveDestroysTheStorage() throws {
        try storage.store(args: ["arg1"])

        _ = try storage.retrieveAll()
        XCTAssertThrowsError(try storage.retrieveAll())
    }

    func testRetrieveDeletesStorageWithLockProtection() throws {
        let ex = expectation(description: "storage retrieves")
        ex.expectedFulfillmentCount = 2
        try storage.store(args: ["arg1"])

        var invocation1: [[String]] = []
        var invocation2: [[String]] = []
        DispatchQueue.global(qos: .default).async {
            invocation1 = (try? self.storage.retrieveAll()) ?? []
            ex.fulfill()
        }
        DispatchQueue.global(qos: .default).async {
            invocation2 = (try? self.storage.retrieveAll()) ?? []
            ex.fulfill()
        }

        waitForExpectations(timeout: Self.timeout)
        XCTAssertEqual(invocation1 + invocation2, [[command, "arg1"]])
    }
}
