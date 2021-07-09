/// Logger to log events to the statistics database
protocol StatsLogger {
    /// Increments a counter related to the action
    func log(_ event: XCRemoteCacheStatistics.Counter) throws
}

/// Coordinator to read and modify XCRemoteCache statistics
protocol StatsCoordinator: StatsLogger {
    /// Fetches all statistics
    func readStats() throws -> XCRemoteCacheStatistics
    /// Resets all statistic counters
    func reset() throws
}
