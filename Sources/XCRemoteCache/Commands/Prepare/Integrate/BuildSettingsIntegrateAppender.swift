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

typealias BuildSettings = [String: Any]

// Manages Xcode build settings
protocol BuildSettingsIntegrateAppender {
    /// Appends XCRemoteCache-specific build settings
    /// - Parameters:
    ///   - buildSettings: original build settings
    ///   - wrappers: definition of XCRemoteCache binaries location
    func appendToBuildSettings(buildSettings: BuildSettings, wrappers: XCRCBinariesPaths) -> BuildSettings
}

class XcodeProjBuildSettingsIntegrateAppender: BuildSettingsIntegrateAppender {
    private let mode: Mode
    private let repoRoot: URL

    init(mode: Mode, repoRoot: URL) {
        self.mode = mode
        self.repoRoot = repoRoot
    }

    func appendToBuildSettings(buildSettings: BuildSettings, wrappers: XCRCBinariesPaths) -> BuildSettings {
        var result = buildSettings
        result["SWIFT_EXEC"] = wrappers.swiftc.path
        // When generating artifacts, no need to shell-out all compilation commands to our wrappers
        if case .consumer = mode {
            result["CC"] = wrappers.cc.path
            result["LD"] = wrappers.ld.path
            result["LIBTOOL"] = wrappers.libtool.path
        }

        let existingSwiftFlags = result["OTHER_SWIFT_FLAGS"] as? String
        let existingCFlags = result["OTHER_CFLAGS"] as? String
        var swiftFlags = XcodeSettingsSwiftFlags(settingValue: existingSwiftFlags)
        var clangFlags = XcodeSettingsCFlags(settingValue: existingCFlags)

        // Overriding debug prefix map for Swift and ObjC to have consistent absolute path for all debug symbols
        swiftFlags.assignFlag(key: "debug-prefix-map", value: "\(repoRoot.path)=$(XCRC_FAKE_SRCROOT)")
        clangFlags.assignFlag(key: "debug-prefix-map", value: "\(repoRoot.path)=$(XCRC_FAKE_SRCROOT)")

        result["OTHER_SWIFT_FLAGS"] = swiftFlags.settingValue
        result["OTHER_CFLAGS"] = clangFlags.settingValue

        result["XCRC_FAKE_SRCROOT"] = "/\(String(repeating: "x", count: 10))"
        return result
    }
}
