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

/// Logger to log events to the statistics database
protocol CacheHitLogger {
    /// Increments a counter related to the cache hit
    func logHit() throws
    /// Increments a counter related to the cache miss
    func logMiss() throws
}

/// Logs target hit or miss, based on an action of a build
class ActionSpecificCacheHitLogger: CacheHitLogger {
    private let statsLogger: StatsLogger
    private let hitCounter: XCRemoteCacheStatistics.Counter?
    private let missCounter: XCRemoteCacheStatistics.Counter?

    init(action: BuildActionType, statsLogger: StatsLogger) {
        self.statsLogger = statsLogger
        switch action {
        case .index:
            hitCounter = .indexingTargetHitCount
            missCounter = .indexingTargetMissCount
        case .build:
            hitCounter = .targetCacheHit
            missCounter = .targetCacheMiss
        case .unknown:
            hitCounter = nil
            missCounter = nil
        }
    }

    func logHit() throws {
        if let hitCounter = hitCounter {
            try statsLogger.log(hitCounter)
        }
    }

    func logMiss() throws {
        if let missCounter = missCounter {
            try statsLogger.log(missCounter)
        }
    }
}
