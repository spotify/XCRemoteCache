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

class PostbuildContextTests: FileXCTestCase {
    private var config: XCRemoteCacheConfig!
    private var remoteCommitFile: URL!
    private static let SampleEnvs = [
        "TARGET_NAME": "TARGET_NAME",
        "TARGET_TEMP_DIR": "TARGET_TEMP_DIR",
        "DERIVED_FILE_DIR": "DERIVED_FILE_DIR",
        "ARCHS": "x86_64",
        "OBJECT_FILE_DIR_normal": "/OBJECT_FILE_DIR_normal",
        "CONFIGURATION": "CONFIGURATION",
        "PLATFORM_NAME": "PLATFORM_NAME",
        "XCODE_PRODUCT_BUILD_VERSION": "XCODE_PRODUCT_BUILD_VERSION",
        "TARGET_BUILD_DIR": "TARGET_BUILD_DIR",
        "PRODUCT_MODULE_NAME": "PRODUCT_MODULE_NAME",
        "EXECUTABLE_PATH": "EXECUTABLE_PATH",
        "SRCROOT": "SRCROOT",
        "DEVELOPER_DIR": "DEVELOPER_DIR",
        "MACH_O_TYPE": "MACH_O_TYPE",
        "DWARF_DSYM_FILE_SHOULD_ACCOMPANY_PRODUCT": "DWARF_DSYM_FILE_SHOULD_ACCOMPANY_PRODUCT",
        "DWARF_DSYM_FOLDER_PATH": "DWARF_DSYM_FOLDER_PATH",
        "DWARF_DSYM_FILE_NAME": "DWARF_DSYM_FILE_NAME",
        "BUILT_PRODUCTS_DIR": "BUILT_PRODUCTS_DIR",
        "DERIVED_SOURCES_DIR": "DERIVED_SOURCES_DIR",
        "CURRENT_VARIANT": "normal",
        "PUBLIC_HEADERS_FOLDER_PATH": "/usr/local/include",
        "LLBUILD_BUILD_ID": "1",
    ]

    override func setUpWithError() throws {
        try super.setUpWithError()
        let workingDir = try prepareTempDir()
        remoteCommitFile = workingDir.appendingPathComponent("arc.rc")
        _ = workingDir.appendingPathComponent("mpo")
        config = XCRemoteCacheConfig(remoteCommitFile: remoteCommitFile.path, sourceRoot: workingDir.path)
        config.recommendedCacheAddress = "http://test.com"
    }

    func testValidCommitFileSetsValidConsumer() throws {
        try fileManager.write(toPath: remoteCommitFile.path, contents: "123".data(using: .utf8))
        let context = try PostbuildContext(config, env: Self.SampleEnvs)

        XCTAssertEqual(context.remoteCommit, .available(commit: "123"))
    }

    func testEmptyCommitFileSetsUnavailableConsumer() throws {
        try fileManager.write(toPath: remoteCommitFile.path, contents: nil)
        let context = try PostbuildContext(config, env: Self.SampleEnvs)

        XCTAssertEqual(context.remoteCommit, .unavailable)
    }

    func testMissingCommitFileSetsUnavailableConsumer() throws {
        try fileManager.spt_deleteItem(at: remoteCommitFile)
        let context = try PostbuildContext(config, env: Self.SampleEnvs)

        XCTAssertEqual(context.remoteCommit, .unavailable)
    }

    func testFallbacksActionToUnknown() throws {
        let context = try PostbuildContext(config, env: Self.SampleEnvs)

        XCTAssertEqual(context.action, .unknown)
    }

    func testReadsActionFromEnv() throws {
        var envs = Self.SampleEnvs
        envs["ACTION"] = "indexbuild"
        let context = try PostbuildContext(config, env: envs)

        XCTAssertEqual(context.action, .index)
    }

    func testReadsSingleArch() throws {
        var envs = Self.SampleEnvs
        envs["ARCHS"] = "x86_64"
        let context = try PostbuildContext(config, env: envs)

        XCTAssertEqual(context.arch, "x86_64")
    }

    func testReadsFirstArch() throws {
        var envs = Self.SampleEnvs
        envs["ARCHS"] = "x86_64 arm64"
        let context = try PostbuildContext(config, env: envs)

        XCTAssertEqual(context.arch, "x86_64")
    }

    func testFailsForEmptyArch() throws {
        var envs = Self.SampleEnvs
        envs["ARCHS"] = ""

        XCTAssertThrowsError(try PostbuildContext(config, env: envs))
    }

    func testFailsForMissingArch() throws {
        var envs = Self.SampleEnvs
        envs["ARCHS"] = nil

        XCTAssertThrowsError(try PostbuildContext(config, env: envs))
    }

    func testFindTempDirForCustomVariant() throws {
        var envs = Self.SampleEnvs
        envs["ARCHS"] = "x86_64"
        envs["CURRENT_VARIANT"] = "custom"
        envs["OBJECT_FILE_DIR_custom"] = "/OBJECT_FILE_DIR_custom"

        let context = try PostbuildContext(config, env: envs)

        XCTAssertEqual(context.compilationTempDir, "/OBJECT_FILE_DIR_custom/x86_64")
    }

    func testGenericPublicHeaderDestinationIsSkipped() throws {
        var envs = Self.SampleEnvs
        envs["PUBLIC_HEADERS_FOLDER_PATH"] = "/usr/local/include"

        let context = try PostbuildContext(config, env: envs)

        XCTAssertNil(context.publicHeadersFolderPath)
    }

    func testPublicHeaderFolderIsRelativeToProductsDir() throws {
        var envs = Self.SampleEnvs
        envs["BUILT_PRODUCTS_DIR"] = "/MyBuiltProductsDir"
        envs["PUBLIC_HEADERS_FOLDER_PATH"] = "MyModule.grameworks/Headers"

        let context = try PostbuildContext(config, env: envs)

        XCTAssertEqual(context.publicHeadersFolderPath, "/MyBuiltProductsDir/MyModule.grameworks/Headers")
    }

    func testPublicHeaderFolderPathEnvIsOptional() throws {
        var envs = Self.SampleEnvs
        envs.removeValue(forKey: "PUBLIC_HEADERS_FOLDER_PATH")

        let context = try PostbuildContext(config, env: envs)

        XCTAssertNil(context.publicHeadersFolderPath)
    }

    func testDisabledEnvIsFalseByDefault() throws {
        var envs = Self.SampleEnvs
        envs.removeValue(forKey: "XCRC_DISABLED")

        let context = try PostbuildContext(config, env: envs)

        XCTAssertFalse(context.disabled)
    }

    func testDisabledIsTrueForYesEnv() throws {
        var envs = Self.SampleEnvs
        envs["XCRC_DISABLED"] = "YES"

        let context = try PostbuildContext(config, env: envs)

        XCTAssertTrue(context.disabled)
    }

    func testDisabledIsFalseForNonYesEnv() throws {
        var envs = Self.SampleEnvs
        envs["XCRC_DISABLED"] = "NO"

        let context = try PostbuildContext(config, env: envs)

        XCTAssertFalse(context.disabled)
    }

    func testFailsIfLlBuildIdEnvIsMissing() throws {
        var envs = Self.SampleEnvs
        envs.removeValue(forKey: "LLBUILD_BUILD_ID")

        XCTAssertThrowsError(try PostbuildContext(config, env: envs))
    }

    func testBuildsLockValidFileUrl() throws {
        let context = try PostbuildContext(config, env: Self.SampleEnvs)

        XCTAssertEqual(context.llbuildIdLockFile, "TARGET_TEMP_DIR/1.lock")
    }
}
