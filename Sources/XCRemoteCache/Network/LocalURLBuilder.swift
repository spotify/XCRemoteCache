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

/// Builds local URL location for a remote url
protocol LocalURLBuilder {
    func location(for url: URL) -> URL
}

/// Builds locally cached location for the remote url
class LocalURLBuilderImpl: LocalURLBuilder {
    /// Application-specific location to place all cache files
    private static let remoteCacheDir = "XCRemoteCache"
    let localAddress: URL

    init(cachePath: URL) {
        localAddress = cachePath.appendingPathComponent(Self.remoteCacheDir)
    }

    func location(for url: URL) -> URL {
        let components = ([url.host] + url.pathComponents).compactMap { $0 }
        return components.reduce(localAddress) { prev, component in
            prev.appendingPathComponent(component)
        }
    }
}
