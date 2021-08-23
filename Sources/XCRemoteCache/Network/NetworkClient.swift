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

enum NetworkClientError: Error {
    /// Didn't receive response
    case noResponse
    /// Response body is missing
    case missingBodyResponse
    /// Non 2xx status code
    case unsuccessfulResponse(status: Int)
    /// Session returned invalid response (missing both response and error or non-HTTP response)
    case inconsistentSession
    /// Request failed with a timeout
    case timeout
    case other(Error)
}

/// Communication layer for the netowork requests
protocol NetworkClient {
    func fileExists(_ url: URL, completion: @escaping (Result<Bool, NetworkClientError>) -> Void)
    func fetch(_ url: URL, completion: @escaping (Result<Data, NetworkClientError>) -> Void)
    func download(_ url: URL, to location: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void)
    func upload(_ file: URL, as url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void)
    /// Creates an empty file at the remote location
    func create(_ url: URL, completion: @escaping (Result<Void, NetworkClientError>) -> Void)
}

/// Extensions for synchronous NetworkClient APIs
extension NetworkClient {
    func fetchSynchronously(_ url: URL) throws -> Data {
        return try executeSynchronous(action: fetch, arg: url)
    }

    func downloadSynchronously(_ url: URL, to location: URL) throws {
        return try executeSynchronous(action: download, arg1: url, arg2: location)
    }

    func fileExistsSynchronously(_ url: URL) throws -> Bool {
        return try executeSynchronous(action: fileExists, arg: url)
    }

    func uploadSynchronously(_ file: URL, as url: URL) throws {
        return try executeSynchronous(action: upload, arg1: file, arg2: url)
    }

    func createSynchronously(_ url: URL) throws {
        return try executeSynchronous(action: create, arg: url)
    }

    /// Converts async API action with 1 argument to a sync one
    private func executeSynchronous<A, T>(
        action: (A, @escaping (Result<T, NetworkClientError>) -> Void) -> Void,
        arg: A
    ) throws -> T {
        var result: Result<T, NetworkClientError> = .failure(.noResponse)
        let semaphore = DispatchSemaphore(value: 0)
        action(arg) { receivedResult in
            result = receivedResult
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        return try result.get()
    }

    /// Converts async API action with 2 arguments to a sync one
    private func executeSynchronous<A1, A2, T>(
        action: (A1, A2, @escaping (Result<T, NetworkClientError>) -> Void) -> Void,
        arg1: A1,
        arg2: A2
    ) throws -> T {
        var result: Result<T, NetworkClientError> = .failure(.noResponse)
        let semaphore = DispatchSemaphore(value: 0)
        action(arg1, arg2) { receivedResult in
            result = receivedResult
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        return try result.get()
    }
}
