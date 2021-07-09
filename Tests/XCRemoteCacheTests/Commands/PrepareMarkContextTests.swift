@testable import XCRemoteCache
import XCTest

class PrepareMarkContextTests: XCTestCase {

    var config: XCRemoteCacheConfig!

    override func setUp() {
        super.setUp()
        config = XCRemoteCacheConfig(sourceRoot: "/Root")
        config.recommendedCacheAddress = "https://cache.com"
    }

    func testAbsoluteRepoPathsIsSupported() throws {
        let repoPath = "/AbsolutePath"
        config.repoRoot = repoPath

        let context = try PrepareMarkContext(config)

        XCTAssertEqual(context.repoRoot.path, repoPath)
    }

    func testRelativeRepoPathIsSupported() throws {
        let repoPath = "."
        config.repoRoot = repoPath

        let context = try PrepareMarkContext(config)

        XCTAssertEqual(context.repoRoot.path, "/Root")
    }
}
