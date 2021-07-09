import Foundation

/// Builds local URL location for a remote url
protocol LocalURLBuilder {
    func location(for url: URL) -> URL
}

/// Builds locally cached location for the remote url
class LocalURLBuilderImpl: LocalURLBuilder {
    /// Application-specific location to place all cache files
    private static let remoteCacheDir = "XCRemoteCache"
    let localAddress: URL

    init(cachePath: URL) {
        localAddress = cachePath.appendingPathComponent(Self.remoteCacheDir)
    }

    func location(for url: URL) -> URL {
        let components = ([url.host] + url.pathComponents).compactMap { $0 }
        return components.reduce(localAddress) { prev, component in
            prev.appendingPathComponent(component)
        }
    }
}
