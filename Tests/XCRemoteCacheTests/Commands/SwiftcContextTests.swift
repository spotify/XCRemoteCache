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

class SwiftcContextTests: FileXCTestCase {

    private var config: XCRemoteCacheConfig!
    private var input: SwiftcArgInput!
    private var remoteCommitFile: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let workingDir = try prepareTempDir()
        remoteCommitFile = workingDir.appendingPathComponent("arc.rc")
        let modulePathOutput = workingDir.appendingPathComponent("mpo")
        config = XCRemoteCacheConfig(remoteCommitFile: remoteCommitFile.path, sourceRoot: workingDir.path)
        input = SwiftcArgInput(
            objcHeaderOutput: "Target-Swift.h",
            moduleName: "Target",
            modulePathOutput: modulePathOutput.path,
            filemap: "",
            target: "",
            fileList: ""
        )
        try fileManager.write(toPath: remoteCommitFile.path, contents: "123".data(using: .utf8))
    }

    func testValidCommitFileSetsValidConsumer() throws {
        let context = try SwiftcContext(config: config, input: input)

        XCTAssertEqual(context.mode, .consumer(commit: .available(commit: "123")))
    }

    func testEmptyCommitFileSetsUnavailableConsumer() throws {
        try fileManager.write(toPath: remoteCommitFile.path, contents: nil)
        let context = try SwiftcContext(config: config, input: input)

        XCTAssertEqual(context.mode, .consumer(commit: .unavailable))
    }

    func testMissingCommitFileSetsUnavailableConsumer() throws {
        try fileManager.spt_deleteItem(at: remoteCommitFile)
        let context = try SwiftcContext(config: config, input: input)

        XCTAssertEqual(context.mode, .consumer(commit: .unavailable))
    }

    func testProducerModeWhenFileWithCommitShaExistsIsResolvedToProducerFast() throws {
        config.mode = .producerFast
        let context = try SwiftcContext(config: config, input: input)

        XCTAssertEqual(context.mode, .producerFast)
    }

    func testProducerModeWhenFileWithCommitShaDoesntExxistIsResolvedToProducer() throws {
        config.mode = .producerFast
        try fileManager.spt_deleteItem(at: remoteCommitFile)
        let context = try SwiftcContext(config: config, input: input)

        XCTAssertEqual(context.mode, .producer)
    }
}
