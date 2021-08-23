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

/// Representation of all statistics related to XCRemoteCache
struct XCRemoteCacheStatistics: Encodable {
    // Yams library doesn't support encoding strategy, see https://github.com/jpsim/Yams/issues/84
    enum CodingKeys: String, CodingKey {
        case hitCount = "hit_count"
        case missCount = "miss_count"
        case localCacheBytes = "local_cache_bytes"
    }

    /// Counters fields position: rawValue defines the index of the counter
    /// that backs up the statistic metric
    enum Counter: Int, CaseIterable {
        // Warning! Do not add between existing fieds, only add new one at the bottom
        // rawValue represents the counter position
        // e.g. '0' means that 'hitCount' metric will
        // be stored in a first counter (in a file)
        case targetCacheHit = 0
        case targetCacheMiss
    }

    /// Number of cache hits
    let hitCount: Int
    /// Number of cache mises
    let missCount: Int
    /// Size of a local cache in bytes
    let localCacheBytes: Int

    static let initial = XCRemoteCacheStatistics(hitCount: 0, missCount: 0, localCacheBytes: 0)
}

extension XCRemoteCacheStatistics {
    func with(
        hitCount: Int? = nil,
        missCount: Int? = nil,
        localCacheBytes: Int? = nil
    ) -> XCRemoteCacheStatistics {
        return XCRemoteCacheStatistics(
            hitCount: hitCount ?? self.hitCount,
            missCount: missCount ?? self.missCount,
            localCacheBytes: localCacheBytes ?? self.localCacheBytes
        )
    }
}
