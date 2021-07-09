@testable import XCRemoteCache
import XCTest

class FileStatsCoordinatorTests: XCTestCase {
    private let sampleFile = URL(fileURLWithPath: "sample")
    private var coordinator: FileStatsCoordinator!
    private var counters: CountersFake?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let counterFactory: FileStatsCoordinator.CountersFactory = { [weak self] _, size in
            let counters = CountersFake(size)
            self?.counters = counters
            return counters
        }
        coordinator = try FileStatsCoordinator(
            statsLocation: sampleFile,
            cacheLocationDir: sampleFile,
            counterFactory: counterFactory,
            fileManager: FileManager.default
        )
    }

    func testBumpingHitIncrementsFirstCounter() throws {
        try coordinator.log(.targetCacheHit)

        try XCTAssertEqual(counters?.readCounters()[0], 1)
    }

    func testBumpingMissIncrementsSecondCounter() throws {
        try coordinator.log(.targetCacheMiss)

        try XCTAssertEqual(counters?.readCounters()[1], 1)
    }

    func testResetZeroesAllCounters() throws {
        try coordinator.log(.targetCacheMiss)
        try coordinator.log(.targetCacheHit)

        try coordinator.reset()

        try XCTAssertEqual(counters?.readCounters().reduce(0, +), 0)
    }

    func testStatsReportsCounters() throws {
        try coordinator.log(.targetCacheMiss)
        try coordinator.log(.targetCacheHit)
        try coordinator.log(.targetCacheHit)

        let stats = try coordinator.readStats()

        XCTAssertEqual(stats.hitCount, 2)
        XCTAssertEqual(stats.missCount, 1)
    }
}
