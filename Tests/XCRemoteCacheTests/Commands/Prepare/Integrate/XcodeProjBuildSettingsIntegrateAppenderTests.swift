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

class XcodeProjBuildSettingsIntegrateAppenderTests: XCTestCase {
    private let rootURL: URL = "/root"
    private let binariesDir: URL = "/binaries"
    private var buildSettings: BuildSettings!
    private var binaries: XCRCBinariesPaths!

    override func setUp() {
        super.setUp()
        buildSettings = BuildSettings()
        binaries = XCRCBinariesPaths(
            prepare: binariesDir.appendingPathComponent("xcprepare"),
            cc: binariesDir.appendingPathComponent("xccc"),
            swiftc: binariesDir.appendingPathComponent("xcswiftc"),
            libtool: binariesDir.appendingPathComponent("xclibtool"),
            lipo: binariesDir.appendingPathComponent("lipo"),
            ld: binariesDir.appendingPathComponent("xcld"),
            ldplusplus: binariesDir.appendingPathComponent("xcldplusplus"),
            prebuild: binariesDir.appendingPathComponent("xcprebuild"),
            postbuild: binariesDir.appendingPathComponent("xcpostbuild"),
            actool: binariesDir.appendingPathComponent("actool")
        )
    }

    func testProducerSettingFakeSrcRoot() throws {
        let mode: Mode = .producer
        let fakeRootURL: URL = "/xxxxxxxxxxP"
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: fakeRootURL,
            sdksExclude: [],
            options: []
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let resultURL = try XCTUnwrap(result["XCRC_FAKE_SRCROOT"] as? String)

        XCTAssertEqual(resultURL, fakeRootURL.path)
    }

    func testConsumerSettingFakeSrcRoot() throws {
        let mode: Mode = .consumer
        let fakeRootURL: URL = "/xxxxxxxxxxC"
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: fakeRootURL,
            sdksExclude: [],
            options: []
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let resultURL: String = try XCTUnwrap(result["XCRC_FAKE_SRCROOT"] as? String)

        XCTAssertEqual(resultURL, fakeRootURL.path)
    }

    func testConsumerSettingLdPlusPlus() throws {
        let mode: Mode = .consumer
        let fakeRootURL: URL = "/xxxxxxxxxxC"
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: fakeRootURL,
            sdksExclude: [],
            options: []
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let ldPlusPlus: String = try XCTUnwrap(result["LDPLUSPLUS"] as? String)

        XCTAssertEqual(ldPlusPlus, binaries.ldplusplus.path)
    }

    func testSinglesdksExcludeIsAppended() throws {
        let mode: Mode = .consumer
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: "/",
            sdksExclude: ["watchOS*"],
            options: []
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let ldPlusPlusWatchOS: String = try XCTUnwrap(result["LDPLUSPLUS[sdk=watchOS*]"] as? String)

        XCTAssertEqual(ldPlusPlusWatchOS, "")
    }

    func testLibtoolIsSetForExcludedSdks() throws {
        let mode: Mode = .consumer
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: "/",
            sdksExclude: ["watchOS*"],
            options: []
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let libtoolWatchOS: String = try XCTUnwrap(result["LIBTOOL[sdk=watchOS*]"] as? String)

        XCTAssertEqual(libtoolWatchOS, "libtool")
    }

    func testMultiplesdksExcludeAreAppended() throws {
        let mode: Mode = .consumer
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: "/",
            sdksExclude: ["watchOS*", "watchsimulator*"],
            options: []
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let ldPlusPlusWatchOS: String = try XCTUnwrap(result["LDPLUSPLUS[sdk=watchOS*]"] as? String)
        let ldPlusPlusWatchSimulator: String = try XCTUnwrap(result["LDPLUSPLUS[sdk=watchsimulator*]"] as? String)

        XCTAssertEqual(ldPlusPlusWatchOS, "")
        XCTAssertEqual(ldPlusPlusWatchSimulator, "")
    }

    func testAddsDisabledFlagForExcludedSDKs() throws {
        let mode: Mode = .consumer
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: "/",
            sdksExclude: ["watchOS*", "watchsimulator*"],
            options: []
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let disabledWatchOS: String = try XCTUnwrap(result["XCRC_DISABLED[sdk=watchOS*]"] as? String)
        let disabledWatchSimulator: String = try XCTUnwrap(result["XCRC_DISABLED[sdk=watchsimulator*]"] as? String)

        XCTAssertEqual(disabledWatchOS, "YES")
        XCTAssertEqual(disabledWatchSimulator, "YES")
    }

    func testExcludesSwiftFrontendIntegrationForSpecificOption() throws {
        let mode: Mode = .consumer
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: "/",
            sdksExclude: [],
            options: [.disableSwiftDriverIntegration]
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let useSwiftIntegrationDriver: String = try XCTUnwrap(result["SWIFT_USE_INTEGRATED_DRIVER"] as? String)

        XCTAssertEqual(useSwiftIntegrationDriver, "NO")
    }

    func testDoesntExcludesSwiftFrontendIntegrationForEmptyOptions() throws {
        let mode: Mode = .consumer
        let appender = XcodeProjBuildSettingsIntegrateAppender(
            mode: mode,
            repoRoot: rootURL,
            fakeSrcRoot: "/",
            sdksExclude: [],
            options: []
        )
        let result = appender.appendToBuildSettings(buildSettings: buildSettings, wrappers: binaries)
        let useSwiftIntegrationDriver: String? = result["SWIFT_USE_INTEGRATED_DRIVER"] as? String

        XCTAssertNil(useSwiftIntegrationDriver)
    }
}
