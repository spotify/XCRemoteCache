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

class InvocationFileStorageTests: FileXCTestCase {
    private static let timeout = 5.0

    private let command = "swift"
    private var file: URL!
    private var storage: ExistingFileStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        file = try prepareTempDir().appendingPathComponent("file.history")
        try fileManager.spt_createEmptyFile(file)
        storage = ExistingFileStorage(storageFile: file, command: command)
    }

    func testStoresInvocation() throws {
        try storage.store(args: ["arg1", "arg2"])

        let content = fileManager.contents(atPath: file.path)
        XCTAssertEqual(content, "swift\0arg1\0arg2\0\0\n".data(using: .utf8))
    }

    func testAppendsInvocations() throws {
        try storage.store(args: ["arg1"])
        try storage.store(args: ["arg2"])

        let content = fileManager.contents(atPath: file.path)
        XCTAssertEqual(content, "swift\0arg1\0\0\nswift\0arg2\0\0\n".data(using: .utf8))
    }

    func testRetrievesEmptyStorage() throws {
        let fetchedInvocations = try storage.retrieveAll()

        XCTAssertEqual(fetchedInvocations, [])
    }

    func testRetrievesPreviousInvocations() throws {
        try storage.store(args: ["arg1"])
        try storage.store(args: ["arg2"])

        let fetchedInvocations = try storage.retrieveAll()

        XCTAssertEqual(fetchedInvocations, [[command, "arg1"], [command, "arg2"]])
    }

    func testRetrieveDeletesTheStorage() throws {
        try storage.store(args: ["arg1"])

        _ = try storage.retrieveAll()

        XCTAssertFalse(fileManager.fileExists(atPath: file.path))
    }

    func testRetrieveDestroysTheStorage() throws {
        try storage.store(args: ["arg1"])

        _ = try storage.retrieveAll()
        XCTAssertThrowsError(try storage.retrieveAll())
    }

    func testRetrieveDeletesStorageWithLockProtection() throws {
        let ex = expectation(description: "storage retrieves")
        ex.expectedFulfillmentCount = 2
        try storage.store(args: ["arg1"])

        var invocation1: [[String]] = []
        var invocation2: [[String]] = []
        DispatchQueue.global(qos: .default).async {
            invocation1 = (try? self.storage.retrieveAll()) ?? []
            ex.fulfill()
        }
        DispatchQueue.global(qos: .default).async {
            invocation2 = (try? self.storage.retrieveAll()) ?? []
            ex.fulfill()
        }

        waitForExpectations(timeout: Self.timeout)
        XCTAssertEqual(invocation1 + invocation2, [[command, "arg1"]])
    }
}
