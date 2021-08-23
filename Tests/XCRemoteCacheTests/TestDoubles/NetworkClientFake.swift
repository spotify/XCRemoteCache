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

class NetworkClientFake: NetworkClient {
    private var files: [URL: Data] = [:]
    private let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    func fileExists(_ url: URL, completion: @escaping (Result<Bool, NetworkClientError>) -> Void) {
        completion(.success(files[url] != nil))
    }

    func fetch(_ url: URL, completion: @escaping (Result<Data, NetworkClientError>) -> Void) {
        let result: Result<Data, NetworkClientError>
        if let data = files[url] {
            result = .success(data)
        } else {
            result = .failure(NetworkClientError.missingBodyResponse)
        }
        completion(result)
    }

    func download(_ url: URL, to location: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        let result: Result<Void, NetworkClientError>
        if let data = files[url] {
            fileManager.createFile(atPath: location.path, contents: data, attributes: nil)
            result = .success(())
        } else {
            result = .failure(NetworkClientError.missingBodyResponse)
        }
        completion(result)
    }

    func upload(_ file: URL, as url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        files[url] = fileManager.contents(atPath: file.path)
        completion(.success(()))
    }

    func create(_ url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void) {
        files[url] = Data()
        completion(.success(()))
    }
}
