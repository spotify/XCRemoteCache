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

class LowestLatencyNetworkServerProbeTests: XCTestCase {
    private var probe: LowestLatencyNetworkServerProbe!

    func testPicksTheFastestServer() throws {
        let urlFast = try URL(string: "http://fast.com").unwrap()
        let urlSlow = try URL(string: "http://slow.com").unwrap()
        let delays: [String: TimeInterval] = ["fast.com": 0.01, "slow.com": 0.1]
        let networkClient = DelayEmulatedNetworkClientFake(hostsDelays: delays, fileManager: FileManager.default)
        let probe = try LowestLatencyNetworkServerProbe(
            servers: [urlFast, urlSlow],
            healthPath: "health",
            probes: 1,
            fallbackServer: nil,
            networkClient: networkClient
        )

        let serverToUse = try probe.determineRemoteServer()

        XCTAssertEqual(serverToUse, urlFast)
    }

    func testFailsToInitializeWithNonPositiveProbes() {
        XCTAssertThrowsError(try LowestLatencyNetworkServerProbe(
            servers: [],
            healthPath: "health",
            probes: 0,
            fallbackServer: nil,
            networkClient: NetworkClientFake(fileManager: FileManager.default)
        ))
    }

    func testFailsIfRemotesAreUnreachable() throws {
        let url = try URL(string: "http://fast.com").unwrap()
        let probe = try LowestLatencyNetworkServerProbe(
            servers: [url],
            healthPath: "",
            probes: 1,
            fallbackServer: nil,
            networkClient: TimeoutingNetworkClient()
        )

        XCTAssertThrowsError(try probe.determineRemoteServer())
    }
}

class DelayEmulatedNetworkClientFake: NetworkClientFake {
    private let hostsDelays: [String: TimeInterval]

    init(hostsDelays: [String: TimeInterval], fileManager: FileManager) {
        self.hostsDelays = hostsDelays
        super.init(fileManager: fileManager)
    }

    override func fileExists(_ url: URL, completion: @escaping (Result<Bool, NetworkClientError>) -> Void) {
        guard let host = url.host, let delay = hostsDelays[host] else {
            super.fileExists(url, completion: completion)
            return
        }
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) {
            super.fileExists(url, completion: completion)
        }
    }
}
