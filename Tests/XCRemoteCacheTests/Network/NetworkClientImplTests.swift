@testable import XCRemoteCache
import XCTest

class NetworkClientImplTests: XCTestCase {
    typealias Completion<R> = (Result<R, NetworkClientError>) -> Void

    private var responses: [URL: URLProtocolStub.Response] {
        get {
            URLProtocolStub.responses
        }
        set {
            URLProtocolStub.responses = newValue
        }
    }

    private var requests: [URLRequest] {
        get {
            URLProtocolStub.requests
        }
        set {
            URLProtocolStub.requests = newValue
        }
    }

    private let successStatus = 200
    private let failureStatus = 400
    private var url: URL!
    private var successResponse: URLResponse!
    private var failureResponse: URLResponse!
    private var session: URLSession!
    private let fileURL = URL(fileURLWithPath: "/sample")
    private var fileManager: FileManager!
    private var client: NetworkClientImpl!

    override func setUpWithError() throws {
        try super.setUpWithError()
        responses = [:]
        requests = []
        url = try URL(string: "http://example.com").unwrap()
        successResponse = try HTTPURLResponse(
            url: url,
            statusCode: successStatus,
            httpVersion: nil,
            headerFields: nil
        ).unwrap()
        failureResponse = try HTTPURLResponse(
            url: url,
            statusCode: failureStatus,
            httpVersion: nil,
            headerFields: nil
        ).unwrap()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        session = URLSession(configuration: configuration)
        fileManager = FileManager.default
        client = NetworkClientImpl(session: session, retries: 0, fileManager: fileManager, awsV4Signature: nil)
    }

    override func tearDown() {
        url = nil
        successResponse = nil
        failureResponse = nil
        client = nil
        session = nil
        fileManager = nil
        requests = []
        responses = [:]
        super.tearDown()
    }

    func waitForResponse<R>(_ action: (@escaping Completion<R>) -> Void) throws -> Result<R, NetworkClientError> {
        let responseExpectation = expectation(description: "RequestResponse")
        var receivedResponse: Result<R, NetworkClientError>?

        action { response in
            receivedResponse = response
            responseExpectation.fulfill()
        }
        waitForExpectations(timeout: 0.1)
        return try receivedResponse.unwrap()
    }

    func testFetch400CompletesWithFailure() throws {
        responses[url] = .success(failureResponse, Data())
        let response = try waitForResponse { client.fetch(url, completion: $0) }

        guard case .failure(.unsuccessfulResponse(failureStatus)) = response else {
            XCTFail("Unexpected response \(response).")
            return
        }
    }

    func testFetch200CompletesWithSuccess() throws {
        responses[url] = .success(successResponse, Data())
        let response = try waitForResponse { client.fetch(url, completion: $0) }

        guard case .success(Data()) = response else {
            XCTFail("Unexpected response \(response).")
            return
        }
    }

    func testUpload200CompletesWithSuccess() throws {
        let fileURL = URL(fileURLWithPath: "/sample")
        responses[url] = .success(successResponse, Data())
        let response = try waitForResponse { client.upload(fileURL, as: url, completion: $0) }

        guard case .success(()) = response else {
            XCTFail("Unexpected response \(response).")
            return
        }
    }

    func testUpload400CompletesWithFailure() throws {
        responses[url] = .success(failureResponse, Data())
        let response = try waitForResponse { client.upload(fileURL, as: url, completion: $0) }

        guard case .failure(.unsuccessfulResponse(failureStatus)) = response else {
            XCTFail("Unexpected response \(response).")
            return
        }
    }

    func testUploadFilureWith400Retries() throws {
        client = NetworkClientImpl(session: session, retries: 2, fileManager: fileManager, awsV4Signature: nil)
        responses[url] = .success(failureResponse, Data())
        _ = try waitForResponse { client.upload(fileURL, as: url, completion: $0) }

        XCTAssertEqual(
            requests.map(\.url),
            Array(repeating: url, count: 3),
            "Expected 3 requests (original + 2 retries)"
        )
    }

    func testUploadSuccessDoesntRetry() throws {
        client = NetworkClientImpl(session: session, retries: 0, fileManager: fileManager, awsV4Signature: nil)
        responses[url] = .success(successResponse, Data())
        _ = try waitForResponse { client.upload(fileURL, as: url, completion: $0) }

        XCTAssertEqual(requests.map(\.url), [url], "Expected 1 request - original only")
    }

    func testFileExits400CompletesWithFalse() throws {
        responses[url] = .success(failureResponse, Data())
        let response = try waitForResponse { client.fileExists(url, completion: $0) }

        guard case .success(false) = response else {
            XCTFail("Unexpected response \(response).")
            return
        }
    }

    func testFileExits200CompletesWithTrue() throws {
        responses[url] = .success(successResponse, Data())
        let response = try waitForResponse { client.fileExists(url, completion: $0) }

        guard case .success(true) = response else {
            XCTFail("Unexpected response \(response).")
            return
        }
    }

    func testFileExitsErrorCompletesWithFailure() throws {
        let response = try waitForResponse { client.fileExists(url, completion: $0) }

        guard case .failure(.other) = response else {
            XCTFail("Unexpected response \(response).")
            return
        }
    }

    func testDownloadTimeoutReportsTimeoutError() throws {
        responses[url] = .timeout
        let response = try waitForResponse { client.fileExists(url, completion: $0) }

        guard case .failure(.timeout) = response else {
            XCTFail("Unexpected response \(response).")
            return
        }
    }

    func testAWSV4SignatureHeader() throws {
        let signature = AWSV4Signature(
            secretKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
            accessKey: "AKIDEXAMPLE",
            region: "us-east-1",
            service: "iam",
            date: Date(timeIntervalSince1970: 1_440_938_160)
        )
        client = NetworkClientImpl(session: session, retries: 0, fileManager: fileManager, awsV4Signature: signature)
        responses[url] = .success(successResponse, Data())
        _ = try waitForResponse { client.fetch(url, completion: $0) }

        XCTAssertEqual(
            "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request, " +
                "SignedHeaders=host;x-amz-content-sha256;x-amz-date, " +
                "Signature=acdb223475463b6ce711b063f199387a7a12bd638e4dccaaeb5efcbf159b6454",
            try requests[0].allHTTPHeaderFields?["Authorization"].unwrap()
        )
    }
}
