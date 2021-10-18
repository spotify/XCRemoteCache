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


class ActionSpecificCacheHitLoggerTests: FileXCTestCase {
    private var coordinator: StatsCoordinator!

    override func setUp() {
        coordinator = InMemoryStatsCoordinator()
    }

    func testReportsBuildHitLogsToAStandardBuild() throws {
        let logger = ActionSpecificCacheHitLogger(action: .build, statsLogger: coordinator)

        try logger.logHit()

        let allStats = try coordinator.readStats()
        XCTAssertEqual(
            allStats,
            .init(
                hitCount: 1,
                missCount: 0,
                localCacheBytes: 0,
                indexingHitCount: 0,
                indexingMissCount: 0
            )
        )
    }

    func testReportsBuildMissToAStandardBuild() throws {
        let logger = ActionSpecificCacheHitLogger(action: .build, statsLogger: coordinator)

        try logger.logMiss()

        let allStats = try coordinator.readStats()
        XCTAssertEqual(
            allStats,
            .init(
                hitCount: 0,
                missCount: 1,
                localCacheBytes: 0,
                indexingHitCount: 0,
                indexingMissCount: 0
            )
        )
    }

    func testReportsIndexbuildHitToIndexingBuild() throws {
        let logger = ActionSpecificCacheHitLogger(action: .index, statsLogger: coordinator)

        try logger.logHit()

        let allStats = try coordinator.readStats()
        XCTAssertEqual(
            allStats,
            .init(
                hitCount: 0,
                missCount: 0,
                localCacheBytes: 0,
                indexingHitCount: 1,
                indexingMissCount: 0
            )
        )
    }

    func testReportsIndexbuildMissToIndexingBuild() throws {
        let logger = ActionSpecificCacheHitLogger(action: .index, statsLogger: coordinator)

        try logger.logMiss()

        let allStats = try coordinator.readStats()
        XCTAssertEqual(
            allStats,
            .init(
                hitCount: 0,
                missCount: 0,
                localCacheBytes: 0,
                indexingHitCount: 0,
                indexingMissCount: 1
            )
        )
    }
}
