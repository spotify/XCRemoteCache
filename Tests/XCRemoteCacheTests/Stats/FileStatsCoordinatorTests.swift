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
