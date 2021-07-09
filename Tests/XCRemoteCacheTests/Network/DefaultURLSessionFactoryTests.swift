@testable import XCRemoteCache
import XCTest

class DefaultURLSessionFactoryTests: XCTestCase {

    private var exampleURL: URL!
    private var config: XCRemoteCacheConfig!

    override func setUpWithError() throws {
        try super.setUpWithError()
        exampleURL = try URL(string: "http://example.com").unwrap()
        config = XCRemoteCacheConfig(sourceRoot: ".")
    }

    override func tearDown() {
        config = nil
        exampleURL = nil
        super.tearDown()
    }


    func testSessionSetsExtraHeaders() throws {
        config.requestCustomHeaders = ["x-auth": "authKey"]
        let session = DefaultURLSessionFactory(config: config).build()

        let task = session.dataTask(with: exampleURL)

        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["x-auth"], "authKey")
    }

    func testSessionAppendsExtraHeadersToExistingRequestHeaders() throws {
        var request = URLRequest(url: exampleURL)
        request.addValue("requestValue", forHTTPHeaderField: "requestHeader")
        config.requestCustomHeaders = ["x-auth": "authKey"]
        let session = DefaultURLSessionFactory(config: config).build()

        let task = session.dataTask(with: request)

        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["x-auth"], "authKey")
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["requestHeader"], "requestValue")
    }
}
