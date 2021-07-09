import Foundation
@testable import XCRemoteCache
import XCTest

class StringToSignTest: XCTestCase {

    func testSimpleStringToSign() throws {
        let stringToSign = StringToSign(
            region: "us-east-1",
            service: "service1",
            canonicalRequestHash: "f536975d06c0309214f805bb90ccff089219ecd68b2577efef23edd43b7e1a59",
            date: Date(timeIntervalSince1970: 1_624_524_656)
        )

        XCTAssertEqual(
            stringToSign.value,
            "AWS4-HMAC-SHA256\n" +
                "20210624T085056Z\n" +
                "20210624/us-east-1/service1/aws4_request\n" +
                "f536975d06c0309214f805bb90ccff089219ecd68b2577efef23edd43b7e1a59"
        )
    }
}
