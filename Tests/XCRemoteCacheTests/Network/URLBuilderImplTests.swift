@testable import XCRemoteCache
import XCTest

class URLBuilderImplTests: XCTestCase {

    func testTwoMarkersForOtherSchemasAreDifferent() throws {
        let sampleURL = try XCTUnwrap(URL(string: "https://example.com"))
        let builder1 = URLBuilderImpl(
            address: sampleURL,
            configuration: "",
            platform: "",
            targetName: "",
            xcode: "",
            envFingerprint: "",
            schemaVersion: "1"
        )
        let builder2 = URLBuilderImpl(
            address: sampleURL,
            configuration: "",
            platform: "",
            targetName: "",
            xcode: "",
            envFingerprint: "",
            schemaVersion: "2"
        )

        XCTAssertNotEqual(
            try builder1.location(for: .marker(commit: "a")),
            try builder2.location(for: .marker(commit: "a"))
        )
    }
}
