@testable import XCRemoteCache
import XCTest

class ShellTests: XCTestCase {

    func testSellCallSucceeds() {
        XCTAssertNoThrow(try shellCall("/usr/bin/true", args: [], inDir: nil, environment: nil))
    }

    func testSellFailedCallThrows() {
        XCTAssertThrowsError(try shellCall("/usr/bin/false", args: [], inDir: nil, environment: nil))
    }
}
