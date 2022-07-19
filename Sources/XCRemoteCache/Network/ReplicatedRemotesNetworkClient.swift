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

/// NetworkClient with several upload streams
class ReplicatedRemotesNetworkClient: RemoteNetworkClientImpl {
    private let networkClient: NetworkClient
    private let uploadURLBuilders: [URLBuilder]
    private let uploadBatchSize: Int

    init(_ networkClient: NetworkClient, download: URLBuilder, uploads uploadURLBuilders: [URLBuilder], uploadBatchSize: Int) {
        self.networkClient = networkClient
        self.uploadURLBuilders = uploadURLBuilders
        self.uploadBatchSize = uploadBatchSize
        super.init(networkClient, download)
    }

    /// Uploads file for all remotes in parallel (taken from `uploadURLBuilders`) and waits for all to finish
    override func uploadSynchronously(_ file: URL, as remote: RemoteCacheFile) throws {
        let urls = try uploadURLBuilders.map { builder in
            try builder.location(for: remote)
        }

        let group = DispatchGroup()
        var results: [Result<Void, NetworkClientError>] = Array(repeating: .failure(.noResponse), count: urls.count)
        urls.enumerated().forEach { index, url in
            if uploadBatchSize > 0 && index > 0 && index % uploadBatchSize == 0 {
                group.wait()
            }
            group.enter()
            networkClient.upload(file, as: url) { receivedResult in
                results[index] = receivedResult
                group.leave()
            }
        }
        group.wait()
        try results.forEach { try $0.get() }
    }

    /// Create a file for all remotes in parallel (taken from `uploadURLBuilders`) and waits for all to finish
    override func createSynchronously(_ remote: RemoteCacheFile) throws {
        let urls = try uploadURLBuilders.map { builder in
            try builder.location(for: remote)
        }

        let group = DispatchGroup()
        var results: [Result<Void, NetworkClientError>] = Array(repeating: .failure(.noResponse), count: urls.count)
        urls.enumerated().forEach { index, url in
            if uploadBatchSize > 0 && index > 0 && index % uploadBatchSize == 0 {
                group.wait()
            }
            group.enter()
            networkClient.create(url) { receivedResult in
                results[index] = receivedResult
                group.leave()
            }
        }
        group.wait()
        try results.forEach { try $0.get() }
    }
}
