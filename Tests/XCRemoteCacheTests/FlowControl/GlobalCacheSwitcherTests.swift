import Foundation
import XCTest

@testable import XCRemoteCache

class FileGlobalCacheSwitcherTests: XCTestCase {

    private var storageFile: URL!
    private var switcher: GlobalCacheSwitcher!
    private var fileAccessor: FileAccessor!

    override func setUp() {
        super.setUp()
        storageFile = "/storage.file"
        fileAccessor = FileAccessorFake(mode: .strict)
        switcher = FileGlobalCacheSwitcher(storageFile, fileAccessor: fileAccessor)
    }

    func testEnableSavesToFileSha() throws {
        let expectedContent = "1".data(using: .utf8)!

        try switcher.enable(sha: "1")

        let fileContent = try fileAccessor.contents(atPath: storageFile.path)
        XCTAssertEqual(fileContent, expectedContent)
    }

    func testEnableOverridesSha() throws {
        let expectedContent = "1".data(using: .utf8)!
        try fileAccessor.write(toPath: storageFile.path, contents: "-1".data(using: .utf8))

        try switcher.enable(sha: "1")

        let fileContent = try fileAccessor.contents(atPath: storageFile.path)
        XCTAssertEqual(fileContent, expectedContent)
    }

    func testDisableCleansFileContent() throws {
        try fileAccessor.write(toPath: storageFile.path, contents: "Some".data(using: .utf8))

        try switcher.disable()

        let fileContent = try fileAccessor.contents(atPath: storageFile.path)
        XCTAssertEqual(fileContent, Data())
    }

    func testDisableDoesCreateFileWhenFileDoesNotExist() throws {
        try switcher.disable()

        let fileExists = fileAccessor.fileExists(atPath: storageFile.path)
        XCTAssertFalse(fileExists)
    }
}
