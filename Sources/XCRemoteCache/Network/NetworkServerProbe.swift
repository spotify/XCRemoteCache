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

enum NetworkServerProbeError: Error {
    /// none of the servers are alive
    case noServerAlive
    /// Number of probes is invalid
    case invalidProbes(probes: Int)
}

/// Determines the best remote server to use
protocol NetworkServerProbe {
    /// Finds the best remote server to use
    func determineRemoteServer() throws -> URL
}

/// Picks the remote server with the losest latency for a health request
class LowestLatencyNetworkServerProbe: NetworkServerProbe {
    private let servers: [URL]
    private let healthPath: String
    private let probes: Int
    private let fallbackServer: URL?
    private let networkClient: NetworkClient

    init(servers: [URL], healthPath: String, probes: Int, fallbackServer: URL?, networkClient: NetworkClient) throws {
        self.servers = servers
        self.fallbackServer = fallbackServer
        guard probes > 0 else {
            throw NetworkServerProbeError.invalidProbes(probes: probes)
        }
        self.probes = probes
        self.networkClient = networkClient
        self.healthPath = healthPath
    }

    /// Makes the probe synchronous request to all servers and selects the fastest one - the one with the lowest latency
    /// - Throws: `NetworkServerProbeError` if none of servers are alive and no fallback is provided
    /// - Returns: URL address of the fastest server
    func determineRemoteServer() throws -> URL {
        let fastest: (URL?, TimeInterval) = servers.reduce(
            (nil, TimeInterval.greatestFiniteMagnitude)
        ) { prev, serverURL in
            let probeURL = serverURL.appendingPathComponent(healthPath)
            do {
                let minDuration = try (0..<probes).map { _ -> TimeInterval in
                    let start = Date()
                    _ = try networkClient.fileExistsSynchronously(probeURL)
                    return Date().timeIntervalSince(start)
                }.min() ?? 0
                if minDuration < prev.1 {
                    return (serverURL, minDuration)
                }
            } catch {
                // don't consider that server if the request failed (e.g. no VPN access)
            }
            return prev
        }
        guard let fastestURL = fastest.0 else {
            if let fallbackURL = fallbackServer {
                return fallbackURL
            }
            throw NetworkServerProbeError.noServerAlive
        }
        return fastestURL
    }
}
