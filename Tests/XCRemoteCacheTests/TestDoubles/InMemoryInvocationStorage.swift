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

/// Fake that stores all invocations in memory
class InMemoryInvocationStorage: InvocationStorage {
    private let command: String
    private var invocations: [[String]]? = []

    init(command: String) {
        self.command = command
    }

    func store(args: [String]) throws {
        guard invocations != nil else {
            throw "Storage destroyed"
        }
        invocations?.append([command] + args)
    }

    func retrieveAll() throws -> [[String]] {
        defer {
            invocations = nil
        }
        return try invocations.unwrap()
    }
}

/// Storage that incorrectly returnes invocations (a list of empty commands)
class CorruptedInMemoryInvocationStorage: InvocationStorage {
    private let command: String
    private var invocations: [[String]]? = []

    init(command: String) {
        self.command = command
    }

    func store(args: [String]) throws {
        guard invocations != nil else {
            throw "Storage destroyed"
        }
        invocations?.append([command] + args)
    }

    func retrieveAll() throws -> [[String]] {
        defer {
            invocations = nil
        }
        return try invocations.unwrap().map { _ in [] }
    }
}
