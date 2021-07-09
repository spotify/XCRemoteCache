@testable import XCRemoteCache
import XCTest

class FileLLDBInitPatcherTests: XCTestCase {
    private var accessor: FileAccessorFake!
    private let lldbInitPath = URL(fileURLWithPath: "/.lldbinit")
    private let rootURL: URL = "/root"
    private let fakeRootURL: URL = "/xxxxxxxxxx"
    private var patcher: FileLLDBInitPatcher!

    override func setUp() {
        accessor = FileAccessorFake(mode: .normal)
        patcher = FileLLDBInitPatcher(
            file: lldbInitPath,
            rootURL: rootURL,
            fakeSrcRoot: fakeRootURL,
            fileAccessor: accessor
        )
    }

    func testCreatesNewFile() throws {
        let expectedContent: Data = """
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testAppendsAtTheEndOfFile() throws {
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """
        try accessor.write(toPath: lldbInitPath.path, contents: "previous_content")

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testReplacesExistingScript() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        historical_RC_content
        --
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root
        --
        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testRecoversCorruptedLLDBInit() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testDeletesDuplicatedRCEntries() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        value1
        #RemoteCacheCustomSourceMap
        value2
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testDeletesExcessiveRCEntries() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root
        #RemoteCacheCustomSourceMap
        value2
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testDeletesCorruptedExcessiveRCEntries() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root
        #RemoteCacheCustomSourceMap
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }
}
