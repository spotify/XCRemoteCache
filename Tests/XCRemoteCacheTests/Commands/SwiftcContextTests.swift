@testable import XCRemoteCache
import XCTest

class SwiftcContextTests: FileXCTestCase {

    private var config: XCRemoteCacheConfig!
    private var input: SwiftcArgInput!
    private var remoteCommitFile: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let workingDir = try prepareTempDir()
        remoteCommitFile = workingDir.appendingPathComponent("arc.rc")
        let modulePathOutput = workingDir.appendingPathComponent("mpo")
        config = XCRemoteCacheConfig(remoteCommitFile: remoteCommitFile.path, sourceRoot: workingDir.path)
        input = SwiftcArgInput(
            objcHeaderOutput: "Target-Swift.h",
            moduleName: "",
            modulePathOutput: modulePathOutput.path,
            filemap: "",
            target: "",
            fileList: ""
        )
        try fileManager.write(toPath: remoteCommitFile.path, contents: "123".data(using: .utf8))
    }

    func testValidCommitFileSetsValidConsumer() throws {
        let context = try SwiftcContext(config: config, input: input)

        XCTAssertEqual(context.mode, .consumer(commit: .available(commit: "123")))
    }

    func testEmptyCommitFileSetsUnavailableConsumer() throws {
        try fileManager.write(toPath: remoteCommitFile.path, contents: nil)
        let context = try SwiftcContext(config: config, input: input)

        XCTAssertEqual(context.mode, .consumer(commit: .unavailable))
    }

    func testMissingCommitFileSetsUnavailableConsumer() throws {
        try fileManager.spt_deleteItem(at: remoteCommitFile)
        let context = try SwiftcContext(config: config, input: input)

        XCTAssertEqual(context.mode, .consumer(commit: .unavailable))
    }
}
