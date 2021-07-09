@testable import XCRemoteCache
import XCTest

class IncludeExcludeOracleTests: XCTestCase {

    func testExcludes() {
        let oracle = IncludeExcludeOracle(excludes: ["extra"], includes: [])

        XCTAssertFalse(oracle.shouldInclude(identifier: "extra"))
        XCTAssertTrue(oracle.shouldInclude(identifier: "applicable"))
    }

    func testEmptyIncludeAcceptsAllIdentifiers() {
        let oracle = IncludeExcludeOracle(excludes: [], includes: [])

        XCTAssertTrue(oracle.shouldInclude(identifier: "random"))
    }

    func testIncludesOnlyExplicitIdentifiers() {
        let oracle = IncludeExcludeOracle(excludes: [], includes: ["explicit"])

        XCTAssertFalse(oracle.shouldInclude(identifier: "other"))
        XCTAssertTrue(oracle.shouldInclude(identifier: "explicit"))
    }

    func testExcludeHasHigherPriority() {
        let oracle = IncludeExcludeOracle(excludes: ["explicit"], includes: ["explicit"])

        XCTAssertFalse(oracle.shouldInclude(identifier: "explicit"))
    }
}
