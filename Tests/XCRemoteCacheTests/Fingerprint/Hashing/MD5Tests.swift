@testable import XCRemoteCache
import XCTest

class MD5Tests: XCTestCase {
    func testEmptyState() {
        let algorithm = MD5Algorithm()

        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testEmptyString() {
        let algorithm = MD5Algorithm()

        algorithm.add("")
        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testNoopForEmptyStrings() {
        let algorithm = MD5Algorithm()

        algorithm.add("")
        algorithm.add("")
        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testSingleHash() {
        let algorithm = MD5Algorithm()

        algorithm.add("The quick brown fox jumps over the lazy dog")
        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "9e107d9d372bb6826bd81d3542a419d6")
    }

    func testMultipleHash() {
        let algorithm = MD5Algorithm()

        algorithm.add("The quick brown fox jumps over the lazy dog")
        algorithm.add(".")

        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "e4d909c290d0fb1ca068ffaddf22cbd0")
    }
}
