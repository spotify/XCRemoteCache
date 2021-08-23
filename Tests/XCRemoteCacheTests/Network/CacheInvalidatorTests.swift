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

class CacheInvalidatorTests: XCTestCase {

    private var invalidator: LocalCacheInvalidator!
    private var temporaryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        // Set eviction policy to be at most 30 days
        invalidator = LocalCacheInvalidator(localCacheURL: temporaryURL, maximumAgeInDays: 30)
    }

    func testLocalCacheInvalidatesOldFile() throws {
        // Create the expected directory structure for an existing remote cache user
        let metaDirURL = temporaryURL.appendingPathComponent("meta", isDirectory: true)
        try FileManager.default.createDirectory(at: metaDirURL, withIntermediateDirectories: true)
        let fileDirURL = temporaryURL.appendingPathComponent("file", isDirectory: true)
        try FileManager.default.createDirectory(at: fileDirURL, withIntermediateDirectories: true)
        // Create one file that is 60 days old and one that is 10 days old
        let oldFileURL = metaDirURL.appendingPathComponent("old_file.json")
        try Data().write(to: oldFileURL)
        try FileManager.default.setAttributes(
            [FileAttributeKey.creationDate: Date().daysAgo(days: 60)!],
            ofItemAtPath: oldFileURL.path
        )

        let newFileURL = metaDirURL.appendingPathComponent("new_file.json")
        try Data().write(to: newFileURL)
        try FileManager.default.setAttributes(
            [FileAttributeKey.creationDate: Date().daysAgo(days: 10)!],
            ofItemAtPath: newFileURL.path
        )

        // We expect only the oldest to be evicted
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldFileURL.path))
        invalidator.invalidateArtifacts()
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFileURL.path))
    }

    func testLocalCacheInvalidatesEvenIfNoFilesDirectory() throws {
        // Create only a meta directory structure for a first-time remote cache user
        let metaDirURL = temporaryURL.appendingPathComponent("meta", isDirectory: true)
        try FileManager.default.createDirectory(at: metaDirURL, withIntermediateDirectories: true)
        // Create one file that is 60 days old and one that is 10 days old
        let oldFileURL = metaDirURL.appendingPathComponent("old_file.json")
        try Data().write(to: oldFileURL)
        try FileManager.default.setAttributes(
            [FileAttributeKey.creationDate: Date().daysAgo(days: 40)!],
            ofItemAtPath: oldFileURL.path
        )

        let newFileURL = metaDirURL.appendingPathComponent("new_file.json")
        try Data().write(to: newFileURL)
        try FileManager.default.setAttributes(
            [FileAttributeKey.creationDate: Date().daysAgo(days: 5)!],
            ofItemAtPath: newFileURL.path
        )

        // We expect only the oldest to be evicted
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldFileURL.path))
        invalidator.invalidateArtifacts()
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFileURL.path))
    }
}
