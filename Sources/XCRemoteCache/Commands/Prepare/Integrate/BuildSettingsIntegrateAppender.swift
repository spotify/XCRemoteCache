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

struct BuildSettingsIntegrateAppenderOption: OptionSet {
    let rawValue: Int

    static let disableSwiftDriverIntegration = BuildSettingsIntegrateAppenderOption(rawValue: 1 << 0)
}
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
    private let fakeSrcRoot: URL
    private let sdksExclude: [String]
    private let options: BuildSettingsIntegrateAppenderOption

    init(
        mode: Mode,
        repoRoot: URL,
        fakeSrcRoot: URL,
        sdksExclude: [String],
        options: BuildSettingsIntegrateAppenderOption
    ) {
        self.mode = mode
        self.repoRoot = repoRoot
        self.fakeSrcRoot = fakeSrcRoot
        self.sdksExclude = sdksExclude
        self.options = options
    }

    func appendToBuildSettings(buildSettings: BuildSettings, wrappers: XCRCBinariesPaths) -> BuildSettings {
        var result = buildSettings
        setBuildSetting(buildSettings: &result, key: "SWIFT_EXEC", value: wrappers.swiftc.path )
        if options.contains(.disableSwiftDriverIntegration) {
            setBuildSetting(buildSettings: &result, key: "SWIFT_USE_INTEGRATED_DRIVER", value: "NO" )
        }
        // When generating artifacts, no need to shell-out all compilation commands to our wrappers
        if case .consumer = mode {
            setBuildSetting(buildSettings: &result, key: "CC", value: wrappers.cc.path )
            setBuildSetting(buildSettings: &result, key: "LD", value: wrappers.ld.path )
            // Setting LIBTOOL to '' breaks SwiftDriver intengration so resetting it to the original value
            // 'libtool' for all excluded configurations
            setBuildSetting(
                buildSettings: &result,
                key: "LIBTOOL",
                value: wrappers.libtool.path,
                excludedValue: "libtool"
            )
            setBuildSetting(buildSettings: &result, key: "LIPO", value: wrappers.lipo.path )
            setBuildSetting(buildSettings: &result, key: "LDPLUSPLUS", value: wrappers.ldplusplus.path )
            setBuildSetting(buildSettings: &result, key: "ASSETCATALOG_EXEC", value: wrappers.actool.path )
        }

        let existingSwiftFlags = result["OTHER_SWIFT_FLAGS"] as? String
        let existingCFlags = result["OTHER_CFLAGS"] as? String
        var swiftFlags = XcodeSettingsSwiftFlags(settingValue: existingSwiftFlags)
        var clangFlags = XcodeSettingsCFlags(settingValue: existingCFlags)

        // Overriding debug prefix map for Swift and ObjC to have consistent absolute path for all debug symbols
        swiftFlags.assignFlag(key: "debug-prefix-map", value: "\(repoRoot.path)=$(XCRC_FAKE_SRCROOT)")
        clangFlags.assignFlag(key: "debug-prefix-map", value: "\(repoRoot.path)=$(XCRC_FAKE_SRCROOT)")

        setBuildSetting(buildSettings: &result, key: "OTHER_SWIFT_FLAGS", value: swiftFlags.settingValue )
        setBuildSetting(buildSettings: &result, key: "OTHER_CFLAGS", value: clangFlags.settingValue )

        setBuildSetting(buildSettings: &result, key: "XCRC_FAKE_SRCROOT", value: "\(fakeSrcRoot.path)" )
        setBuildSetting(buildSettings: &result, key: "XCRC_PLATFORM_PREFERRED_ARCH", value:
        """
        $(LINK_FILE_LIST_$(CURRENT_VARIANT)_$(PLATFORM_PREFERRED_ARCH):dir:standardizepath:file:default=arm64)
        """
        )

        explicitlyDisableSDKs(buildSettings: &result)
        return result
    }

    private func setBuildSetting(buildSettings: inout BuildSettings, key: String, value: String?, excludedValue: String = "") {
        buildSettings[key] = value
        guard value != nil else {
            // no need to exclude as the value will
            return
        }
        // Erase all overrides for a given sdk so a default toolchain is used
        for skippedSDK in sdksExclude {
            buildSettings["\(key)[sdk=\(skippedSDK)]"] = excludedValue
        }
    }

    // For all exlcuded SDKs passes XCRC_DISABLED=TRUE, which will cut-off early the pre_build phase
    private func explicitlyDisableSDKs(buildSettings: inout BuildSettings) {
        for skippedSDK in sdksExclude {
            buildSettings["XCRC_DISABLED[sdk=\(skippedSDK)]"] = "YES"
        }
    }
}
