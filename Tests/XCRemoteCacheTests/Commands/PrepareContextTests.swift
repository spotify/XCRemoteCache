@testable import XCRemoteCache
import XCTest

class PrepareContextTests: XCTestCase {

    var config: XCRemoteCacheConfig!

    override func setUp() {
        super.setUp()
        config = XCRemoteCacheConfig(sourceRoot: "/Root")
        config.primaryRepo = "https://example.com/repo.git"
        config.recommendedCacheAddress = "https://cache.com"
    }

    func testAbsolutePathsAreSupported() throws {
        let commitPath = "/AbsolutePath/arc.rc"
        let xcccPath = "/AbsolutePath/xccc"
        let repoPath = "/AbsolutePath"
        config.remoteCommitFile = commitPath
        config.xcccFile = xcccPath
        config.repoRoot = repoPath

        let context = try PrepareContext(config, offline: false)

        XCTAssertEqual(context.remoteCommitLocation.path, commitPath)
        XCTAssertEqual(context.xcccCommand.path, xcccPath)
        XCTAssertEqual(context.repoRoot.path, repoPath)
    }

    func testRelativePathsAreSupported() throws {
        let commitPath = "relative/arc.rc"
        let xcccPath = "relative/xccc"
        let repoPath = "."
        config.remoteCommitFile = commitPath
        config.xcccFile = xcccPath
        config.repoRoot = repoPath

        let context = try PrepareContext(config, offline: false)

        XCTAssertEqual(context.remoteCommitLocation.path, "/Root/\(commitPath)")
        XCTAssertEqual(context.xcccCommand.path, "/Root/\(xcccPath)")
        XCTAssertEqual(context.repoRoot.path, "/Root")
    }
}
