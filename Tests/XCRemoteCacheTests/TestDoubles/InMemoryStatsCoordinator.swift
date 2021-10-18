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
@testable import XCRemoteCache

/// Fake that manages all logs in memory and reports 0 cached bytes
/// Note: This fake is thread unsafe
class InMemoryStatsCoordinator: StatsCoordinator {
    private var counters = [XCRemoteCacheStatistics.Counter: Int]()

    func log(_ event: XCRemoteCacheStatistics.Counter) throws {
        counters[event, default: 0] += 1
    }

    func readStats() throws -> XCRemoteCacheStatistics {
        XCRemoteCacheStatistics(
            hitCount: counters[.targetCacheHit] ?? 0,
            missCount: counters[.targetCacheMiss] ?? 0,
            localCacheBytes: 0,
            indexingHitCount: counters[.indexingTargetHitCount] ?? 0,
            indexingMissCount: counters[.indexingTargetMissCount] ?? 0
        )
    }

    func reset() throws {
        counters = [:]
    }
}
