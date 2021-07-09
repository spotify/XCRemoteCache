import Foundation


public enum PrepareMarkContextError: Error {
    case invalidAddress(String)
}

public struct PrepareMarkContext {
    /// Path of the git repository
    let repoRoot: URL
    /// Remote address of the remote server
    let recommendedCacheAddress: URL
    /// All remote servers to mark
    let cacheAddresses: [URL]
}

extension PrepareMarkContext {
    init(_ config: XCRemoteCacheConfig) throws {
        let sourceRoot = URL(fileURLWithPath: config.sourceRoot, isDirectory: true)
        repoRoot = URL(fileURLWithPath: config.repoRoot, relativeTo: sourceRoot)
        guard let address = URL(string: config.recommendedCacheAddress) else {
            errorLog("Invalid cache address: \(config.recommendedCacheAddress)")
            throw PrepareMarkContextError.invalidAddress(config.recommendedCacheAddress)
        }
        recommendedCacheAddress = address
        cacheAddresses = try config.cacheAddresses.map(URL.build)
    }
}
