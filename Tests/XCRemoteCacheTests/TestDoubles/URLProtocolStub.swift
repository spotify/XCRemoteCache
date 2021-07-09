import Foundation

class URLProtocolStub: URLProtocol {
    enum Response {
        case success(URLResponse, Data)
        case timeout
    }

    static var responses: [URL: Response] = [:]
    static var requests: [URLRequest] = []
    static let timeoutError = NSError(domain: "URLProtocolStubError", code: NSURLErrorTimedOut, userInfo: nil)

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        if let url = request.url, let response = Self.responses[url] {
            switch response {
            case .success(let urlResponse, let data):
                client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
            case .timeout:
                client?.urlProtocol(self, didFailWithError: Self.timeoutError)
            }
        } else {
            client?.urlProtocol(self, didFailWithError: "Not expected URL")
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
