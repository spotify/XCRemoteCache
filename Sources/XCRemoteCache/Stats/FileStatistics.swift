// Copyright (c) 2021 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

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
            localCacheBytes: countLocalCacheSize(),
            indexingHitCount: counters[XCRemoteCacheStatistics.Counter.indexingTargetHitCount.rawValue],
            indexingMissCount: counters[XCRemoteCacheStatistics.Counter.indexingTargetMissCount.rawValue]
        )
    }

    func reset() throws {
        try counter.reset()
    }
}
