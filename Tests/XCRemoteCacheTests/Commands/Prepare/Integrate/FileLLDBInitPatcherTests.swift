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

class FileLLDBInitPatcherTests: XCTestCase {
    private var accessor: FileAccessorFake!
    private let lldbInitPath = URL(fileURLWithPath: "/.lldbinit")
    private let rootURL: URL = "/root"
    private let fakeRootURL: URL = "/xxxxxxxxxx"
    private var patcher: FileLLDBInitPatcher!

    override func setUp() {
        accessor = FileAccessorFake(mode: .normal)
        patcher = FileLLDBInitPatcher(
            file: lldbInitPath,
            rootURL: rootURL,
            fakeSrcRoot: fakeRootURL,
            fileAccessor: accessor
        )
    }

    func testCreatesNewFile() throws {
        let expectedContent: Data = """
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testAppendsAtTheEndOfFile() throws {
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """
        try accessor.write(toPath: lldbInitPath.path, contents: "previous_content")

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testReplacesExistingScript() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        historical_RC_content
        --
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root
        --
        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testRecoversCorruptedLLDBInit() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testDeletesDuplicatedRCEntries() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        value1
        #RemoteCacheCustomSourceMap
        value2
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testDeletesExcessiveRCEntries() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root
        #RemoteCacheCustomSourceMap
        value2
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }

    func testDeletesCorruptedExcessiveRCEntries() throws {
        let oldContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root
        #RemoteCacheCustomSourceMap
        """
        try accessor.write(toPath: lldbInitPath.path, contents: oldContent)
        let expectedContent: Data = """
        previous_content
        #RemoteCacheCustomSourceMap
        settings set target.source-map /xxxxxxxxxx /root

        """

        try patcher.enable()

        let finalContent = try accessor.contents(atPath: lldbInitPath.path)
        XCTAssertEqual(finalContent, expectedContent)
    }
}
