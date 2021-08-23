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
import XCTest

@testable import XCRemoteCache

class FileGlobalCacheSwitcherTests: XCTestCase {

    private var storageFile: URL!
    private var switcher: GlobalCacheSwitcher!
    private var fileAccessor: FileAccessor!

    override func setUp() {
        super.setUp()
        storageFile = "/storage.file"
        fileAccessor = FileAccessorFake(mode: .strict)
        switcher = FileGlobalCacheSwitcher(storageFile, fileAccessor: fileAccessor)
    }

    func testEnableSavesToFileSha() throws {
        let expectedContent = "1".data(using: .utf8)!

        try switcher.enable(sha: "1")

        let fileContent = try fileAccessor.contents(atPath: storageFile.path)
        XCTAssertEqual(fileContent, expectedContent)
    }

    func testEnableOverridesSha() throws {
        let expectedContent = "1".data(using: .utf8)!
        try fileAccessor.write(toPath: storageFile.path, contents: "-1".data(using: .utf8))

        try switcher.enable(sha: "1")

        let fileContent = try fileAccessor.contents(atPath: storageFile.path)
        XCTAssertEqual(fileContent, expectedContent)
    }

    func testDisableCleansFileContent() throws {
        try fileAccessor.write(toPath: storageFile.path, contents: "Some".data(using: .utf8))

        try switcher.disable()

        let fileContent = try fileAccessor.contents(atPath: storageFile.path)
        XCTAssertEqual(fileContent, Data())
    }

    func testDisableDoesCreateFileWhenFileDoesNotExist() throws {
        try switcher.disable()

        let fileExists = fileAccessor.fileExists(atPath: storageFile.path)
        XCTAssertFalse(fileExists)
    }
}
