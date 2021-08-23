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

class FilteredInvocationStorageTests: XCTestCase {

    let underlyingStorage = InMemoryInvocationStorage(command: "swiftc")
    var storage: FilteredInvocationStorage!

    override func setUp() {
        storage = FilteredInvocationStorage(storage: underlyingStorage, retrieveIgnoredCommands: ["to_ignore"])
    }

    func testStoresInvocations() throws {
        try storage.store(args: ["arg1"])

        XCTAssertEqual(try underlyingStorage.retrieveAll(), [["swiftc", "arg1"]])
    }

    func testRetrivesNonIgnoredInvocations() throws {
        try underlyingStorage.store(args: ["arg1"])

        let invocations = try storage.retrieveAll()

        XCTAssertEqual(invocations, [["swiftc", "arg1"]])
    }

    func testFiltersIgnoredInvocations() throws {
        storage = FilteredInvocationStorage(storage: underlyingStorage, retrieveIgnoredCommands: ["swiftc"])
        try underlyingStorage.store(args: ["arg1"])

        let invocations = try storage.retrieveAll()

        XCTAssertEqual(invocations, [])
    }

    func testThrowsWhenStorageIsCorrupted() throws {
        let corruptedStorage = CorruptedInMemoryInvocationStorage(command: "swiftc")
        try corruptedStorage.store(args: ["arg1"])
        storage = FilteredInvocationStorage(storage: corruptedStorage, retrieveIgnoredCommands: [])

        XCTAssertThrowsError(try storage.retrieveAll())
    }
}
