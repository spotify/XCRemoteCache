import Foundation

/// Logger, backed by a file
class FileStatsLogger: StatsLogger {
    private typealias FileDescriptor = FileHandle
    typealias CountersFactory = (URL, Int) -> Counters

    fileprivate let counter: Counters

    init(
        statsLocation: URL,
        counterFactory: CountersFactory,
        fileManager: FileManager
    ) throws {
        // Create stats if running a first time
        try fileManager.createDirectory(at: statsLocation, withIntermediateDirectories: true, attributes: nil)

        let statsFileLocation = statsLocation.appendingPathComponent("stats", isDirectory: false)
        counter = counterFactory(statsFileLocation, XCRemoteCacheStatistics.Counter.allCases.count)
    }

    func log(_ event: XCRemoteCacheStatistics.Counter) throws {
        try counter.bumpCounter(position: event.rawValue)
    }
}

/// Statistics coordinator that stores all data in a file
class FileStatsCoordinator: FileStatsLogger, StatsCoordinator {
    private let cacheLocationDir: URL
    private let sizeReader: SizeProvider

    init(
        statsLocation: URL,
        cacheLocationDir: URL,
        counterFactory: CountersFactory,
        fileManager: FileManager
    ) throws {
        // Create stats&cache if first running
        try fileManager.createDirectory(at: cacheLocationDir, withIntermediateDirectories: true, attributes: nil)

        sizeReader = DiskUsageSizeProvider(shell: shellGetStdout)
        self.cacheLocationDir = cacheLocationDir
        try super.init(
            statsLocation: statsLocation,
            counterFactory: counterFactory,
            fileManager: fileManager
        )
    }

    private func countLocalCacheSize() throws -> Int {
        return try sizeReader.size(at: cacheLocationDir)
    }

    func readStats() throws -> XCRemoteCacheStatistics {
        let counters = try counter.readCounters()
        return try XCRemoteCacheStatistics(
            hitCount: counters[XCRemoteCacheStatistics.Counter.targetCacheHit.rawValue],
            missCount: counters[XCRemoteCacheStatistics.Counter.targetCacheMiss.rawValue],
            localCacheBytes: countLocalCacheSize()
        )
    }

    func reset() throws {
        try counter.reset()
    }
}
