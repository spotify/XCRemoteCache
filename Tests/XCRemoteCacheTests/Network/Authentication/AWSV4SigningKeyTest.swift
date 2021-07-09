import Foundation
@testable import XCRemoteCache
import XCTest

class AWSV4SigningKeyTest: XCTestCase {

    // Example from:
    // https://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html#signature-v4-examples-other
    func testSigningKeyExample() throws {
        let signature = AWSV4SigningKey(
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
            region: "us-east-1",
            service: "iam",
            date: Date(timeIntervalSince1970: 1_329_267_660)
        )

        XCTAssertEqual(
            signature.value.map { String(format: "%02hhx", $0) }.joined(),
            "f4780e2d9f65fa895f9c67b32ce1baf0b0d8a43505a000a1a9e090d414db404d"
        )
    }
}
