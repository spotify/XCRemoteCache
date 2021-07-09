import Foundation


public enum XCStatsContextError: Error {
    case invalidAddress(String)
}

public struct XCStatsContext {
    /// Path of the root directory with all statistic files
    let statsDir: URL
    /// Location of the local cache that stores all fetched artifacts, metas etc
    let cacheLocation: URL
}

extension XCStatsContext {
    init(_ config: XCRemoteCacheConfig, fileManager: FileManager) throws {

        statsDir = URL(fileURLWithPath: config.statsDir.expandingTildeInPath)
        let cacheURL: URL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheURLBuilder = LocalURLBuilderImpl(cachePath: cacheURL)
        cacheLocation = cacheURLBuilder.localAddress
    }
}
