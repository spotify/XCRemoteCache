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

/// Factory for the RemoteNetworkClient
/// Switches between "single remote" and "mulitple upstream remotes" implementations
class RemoteNetworkClientAbstractFactory {
    private let mode: Mode
    private let downloadStreamURL: URL
    private let upstreamStreamURL: [URL]
    private let networkClient: NetworkClient
    private let urlBuilderFactory: (URL) throws -> URLBuilder

    init(mode: Mode, downloadStreamURL: URL, upstreamStreamURL: [URL], networkClient: NetworkClient, urlBuilderFactory: @escaping (URL) throws -> URLBuilder) {
        self.mode = mode
        self.downloadStreamURL = downloadStreamURL
        self.upstreamStreamURL = upstreamStreamURL
        self.networkClient = networkClient
        self.urlBuilderFactory = urlBuilderFactory
    }

    /// Builds remote network client that uses concrete remote address for download
    /// and multiple uploads (`.producer` mode)
    func build() throws -> RemoteNetworkClient {
        let downloadURLBuilder = try urlBuilderFactory(downloadStreamURL)
        guard !upstreamStreamURL.isEmpty else {
            return RemoteNetworkClientImpl(networkClient, downloadURLBuilder)
        }
        switch mode {
        case .producer:
            let upstreamBuilders = try upstreamStreamURL.map(urlBuilderFactory)
            return ReplicatedRemotesNetworkClient(
                networkClient,
                download: downloadURLBuilder,
                uploads: upstreamBuilders
            )
        case .consumer:
            return RemoteNetworkClientImpl(networkClient, downloadURLBuilder)
        }
    }
}
