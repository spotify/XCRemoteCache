import Foundation
@testable import XCRemoteCache
import XCTest

class AWSV4SignatureTest: XCTestCase {

    var request: URLRequest!

    // Example from
    // https://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html
    override func setUp() {
        super.setUp()
        let url = URL(string: "https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08")!
        request = URLRequest(url: url)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let key = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
        let accessKey = "AKIDEXAMPLE"

        AWSV4Signature(
            secretKey: key,
            accessKey: accessKey,
            region: "us-east-1",
            service: "iam",
            date: Date(timeIntervalSince1970: 1_440_938_160)
        )
        .addSignatureHeaderTo(request: &request)
    }

    func testAuthHeaderContainsCorrectSignature() throws {
        XCTAssertEqual(
            "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request, " +
                "SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date, " +
                "Signature=dd479fa8a80364edf2119ec24bebde66712ee9c9cb2b0d92eb3ab9ccdc0c3947",
            request.allHTTPHeaderFields?["Authorization"]
        )
    }
}
