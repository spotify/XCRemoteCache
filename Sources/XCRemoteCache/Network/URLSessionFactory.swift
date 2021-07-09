import Foundation

protocol URLSessionFactory {
    /// Builds URLSession specific to the current XCRemoteCache configuration
    func build() -> URLSession
}

/// URLSession factory that appends extra headers and uses default configuration
class DefaultURLSessionFactory: URLSessionFactory {
    private let config: XCRemoteCacheConfig

    init(config: XCRemoteCacheConfig) {
        self.config = config
    }

    func build() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = config.requestCustomHeaders
        configuration.timeoutIntervalForRequest = config.timeoutResponseDataChunksInterval
        return URLSession(configuration: configuration)
    }
}
