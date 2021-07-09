@testable import XCRemoteCache
import XCTest

class LocalURLBuilderImplTests: XCTestCase {
    private var invalidator: LocalURLBuilderImpl!

    func testBuilderWrapsAllRequestsWithAppDirectory() throws {
        let cacheURL = URL(fileURLWithPath: "/cache")
        let urlBuilder = LocalURLBuilderImpl(cachePath: cacheURL)
        let remoteURL = try URL(string: "https://address.com/path").unwrap()
        let expectedLocalURL = URL(fileURLWithPath: "/cache/XCRemoteCache/address.com/path")

        let localLocation = urlBuilder.location(for: remoteURL)

        XCTAssertEqual(localLocation, expectedLocalURL)
    }
}
