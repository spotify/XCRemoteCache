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

/// Client for downloading/uploading RemoteCache files
public protocol RemoteNetworkClient {
    /// Checks if the remote location exists
    func fileExists(_ file: RemoteCacheFile) throws -> Bool
    /// Reads content of the remote location
    func fetch(_ file: RemoteCacheFile) throws -> Data
    /// Downloads a file from the remote side to the local location
    func download(_ file: RemoteCacheFile, to location: URL) throws
    /// Uploads a file to the remote location
    func uploadSynchronously(_ file: URL, as remote: RemoteCacheFile) throws
    /// Creates an empty file at the remote location
    func createSynchronously(_ remote: RemoteCacheFile) throws
}

class RemoteNetworkClientImpl: RemoteNetworkClient {
    private let networkClient: NetworkClient
    private let urlBuilder: URLBuilder

    init(_ networkClient: NetworkClient, _ urlBuilder: URLBuilder) {
        self.networkClient = networkClient
        self.urlBuilder = urlBuilder
    }

    func fileExists(_ file: RemoteCacheFile) throws -> Bool {
        let url = try urlBuilder.location(for: file)
        return try networkClient.fileExistsSynchronously(url)
    }

    func fetch(_ file: RemoteCacheFile) throws -> Data {
        let url = try urlBuilder.location(for: file)
        return try networkClient.fetchSynchronously(url)
    }

    func download(_ file: RemoteCacheFile, to location: URL) throws {
        let url = try urlBuilder.location(for: file)
        try networkClient.downloadSynchronously(url, to: location)
    }

    func uploadSynchronously(_ file: URL, as remote: RemoteCacheFile) throws {
        let url = try urlBuilder.location(for: remote)
        try networkClient.uploadSynchronously(file, as: url)
    }

    func createSynchronously(_ remote: RemoteCacheFile) throws {
        let url = try urlBuilder.location(for: remote)
        try networkClient.createSynchronously(url)
    }
}
