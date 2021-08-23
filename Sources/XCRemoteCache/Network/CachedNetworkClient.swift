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

/// NetworkClient that caches responses locally on a disk
class CachedNetworkClient: NetworkClient {
    private let localURLBuilder: LocalURLBuilder
    private let client: NetworkClient
    private let fileManager: FileManager

    init(localURLBuilder: LocalURLBuilder, client: NetworkClient, fileManager: FileManager) {
        self.localURLBuilder = localURLBuilder
        self.client = client
        self.fileManager = fileManager
    }

    func fileExists(_ url: URL, completion: @escaping (Result<Bool, NetworkClientError>) -> Void) {
        let localURL = localURLBuilder.location(for: url)
        if fileManager.fileExists(atPath: localURL.path) {
            completion(.success(true))
            return
        }
        client.fileExists(url, completion: completion)
    }

    func fetch(_ url: URL, completion: @escaping (Result<Data, NetworkClientError>) -> Void) {
        let localURL = localURLBuilder.location(for: url)
        if fileManager.fileExists(atPath: localURL.path), let data = fileManager.contents(atPath: localURL.path) {
            completion(.success(data))
            return
        }
        client.fetch(url) { [fileManager] result in
            completion(result)
            guard case .success(let data) = result else {
                return
            }
            do {
                try fileManager.spt_writeToFile(atPath: localURL.path, contents: data)
            } catch {
                errorLog("Saving to cache location failed with error: \(error)")
            }
        }
    }

    func download(_ url: URL, to location: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        let localURL = localURLBuilder.location(for: url)
        if fileManager.fileExists(atPath: localURL.path) {
            do {
                try fileManager.spt_forceLinkItem(at: localURL, to: location)
                completion(.success(()))
            } catch {
                errorLog("Couldn't link cached file to the expected location with error: \(error)")
                completion(.failure(.other(error)))
            }
            return
        }
        do {
            try fileManager.createDirectory(
                at: localURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            completion(.failure(.other(error)))
            errorLog("Couldn't create a directory for CachedNetworkClient with error: \(error)")
            return
        }

        client.download(url, to: localURL) { [fileManager] result in
            do {
                if case .success = result {
                    try fileManager.spt_forceLinkItem(at: localURL, to: location)
                }
                completion(result)
            } catch {
                errorLog("Couldn't link downloaded file to the expected location with error: \(error)")
                completion(.failure(.other(error)))
            }
        }
    }

    func upload(_ file: URL, as url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        client.upload(file, as: url, completion: completion)
    }

    func create(_ url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        client.create(url, completion: completion)
    }
}
