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

class FileFingerprintSyncerTests: FileXCTestCase {

    private var syncer: FileFingerprintSyncer!
    private var swiftmoduleDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        syncer = FileFingerprintSyncer(
            fingerprintOverrideExtension: "md5",
            dirAccessor: fileManager,
            extensions: ["swiftmodule"]
        )
        swiftmoduleDir = try prepareTempDir().appendingPathComponent("module")
    }

    func testDecorateCreatesValidOverrideFile() throws {
        let swiftmodule = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule")
        let swiftmoduleDecoration = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule.md5")
        try fileManager.spt_createEmptyFile(swiftmodule)

        try syncer.decorate(sourceDir: swiftmoduleDir, fingerprint: "1")

        XCTAssertEqual(try String(contentsOf: swiftmoduleDecoration), "1")
    }

    func testDecorateOverridesPreviousOverrideFile() throws {
        let swiftmodule = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule")
        let swiftmoduleDecoration = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule.md5")
        try fileManager.spt_createEmptyFile(swiftmodule)
        try "1".write(to: swiftmoduleDecoration, atomically: true, encoding: .utf8)

        try syncer.decorate(sourceDir: swiftmoduleDir, fingerprint: "2")

        XCTAssertEqual(try String(contentsOf: swiftmoduleDecoration), "2")
    }

    func testDeleteRemovesOverrideFile() throws {
        let previousOverrideFile = swiftmoduleDir.appendingPathComponent("x86_64.md5")
        try fileManager.spt_createEmptyFile(previousOverrideFile)

        try syncer.delete(sourceDir: swiftmoduleDir)

        XCTAssertFalse(fileManager.fileExists(atPath: previousOverrideFile.path))
    }

    func testDeletesDoesntDeleteNonOverrideFiles() throws {
        let nonOverrideFile = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule")
        try fileManager.spt_createEmptyFile(nonOverrideFile)

        try syncer.delete(sourceDir: swiftmoduleDir)

        XCTAssertTrue(fileManager.fileExists(atPath: nonOverrideFile.path))
    }

    func testDecoratesFile() throws {
        let header = swiftmoduleDir.appendingPathComponent("Module-Swift.h")
        let headerOverride = swiftmoduleDir.appendingPathComponent("Module-Swift.h.md5")
        try fileManager.spt_createEmptyFile(header)


        try syncer.decorate(file: header, fingerprint: "1")

        XCTAssertEqual(try String(contentsOf: headerOverride), "1")
    }

    func testFileDecorateOverridesPreviousOverlay() throws {
        let header = swiftmoduleDir.appendingPathComponent("Module-Swift.h")
        let headerOverride = swiftmoduleDir.appendingPathComponent("Module-Swift.h.md5")
        try fileManager.spt_createEmptyFile(header)
        try "1".write(to: headerOverride, atomically: true, encoding: .utf8)

        try syncer.decorate(file: header, fingerprint: "2")

        XCTAssertEqual(try String(contentsOf: headerOverride), "2")
    }

    func testDeletesFileOverride() throws {
        let header = swiftmoduleDir.appendingPathComponent("Module-Swift.h")
        let headerOverride = swiftmoduleDir.appendingPathComponent("Module-Swift.h.md5")
        try fileManager.spt_createEmptyFile(header)
        try fileManager.spt_createEmptyFile(headerOverride)


        try syncer.delete(file: header)

        XCTAssertFalse(fileManager.fileExists(atPath: headerOverride.path))
    }

    func testDeletesDoesntDeleteWhenFileIsMissing() throws {
        let nonExistingFile = swiftmoduleDir.appendingPathComponent("Module-Swift.h")

        XCTAssertNoThrow(try syncer.delete(file: nonExistingFile))
    }

    func testDeletesDoesntDeleteWhenOverrideIsMissing() throws {
        let header = swiftmoduleDir.appendingPathComponent("Module-Swift.h")
        try fileManager.spt_createEmptyFile(header)

        XCTAssertNoThrow(try syncer.delete(file: header))
    }
}
