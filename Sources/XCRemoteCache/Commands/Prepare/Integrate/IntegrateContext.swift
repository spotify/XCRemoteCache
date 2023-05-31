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

struct IntegrateContext {
    let projectPath: URL
    let repoRoot: URL
    let binaries: XCRCBinariesPaths
    let mode: Mode
    let configOverride: URL
    let fakeSrcRoot: URL
    let output: URL?
    let buildSettingsAppenderOptions: BuildSettingsIntegrateAppenderOption
}

extension IntegrateContext {
    init(
        input: String,
        config: XCRemoteCacheConfig,
        mode: Mode,
        env: [String: String],
        binariesDir: URL,
        fakeSrcRoot: String,
        outputPath: String?
    ) throws {
        projectPath = URL(fileURLWithPath: input)
        let srcRoot = projectPath.deletingLastPathComponent()
        repoRoot = URL(fileURLWithPath: config.repoRoot, relativeTo: srcRoot)
        self.mode = mode
        configOverride = URL(fileURLWithPath: config.extraConfigurationFile, relativeTo: srcRoot)
        output = outputPath.flatMap(URL.init(fileURLWithPath:))
        self.fakeSrcRoot = URL(fileURLWithPath: fakeSrcRoot)
        var swiftcBinaryName = "swiftc"
        var buildSettingsAppenderOptions: BuildSettingsIntegrateAppenderOption = []
        // Keep the legacy behaviour (supported in Xcode 14 and lower)
        if !config.enableSwifDriverIntegration {
            buildSettingsAppenderOptions.insert(.disableSwiftDriverIntegration)
            swiftcBinaryName = "xcswiftc"
        }
        binaries = XCRCBinariesPaths(
            prepare: binariesDir.appendingPathComponent("xcprepare"),
            cc: binariesDir.appendingPathComponent("xccc"),
            swiftc: binariesDir.appendingPathComponent(swiftcBinaryName),
            libtool: binariesDir.appendingPathComponent("xclibtool"),
            lipo: binariesDir.appendingPathComponent("xclipo"),
            ld: binariesDir.appendingPathComponent("xcld"),
            ldplusplus: binariesDir.appendingPathComponent("xcldplusplus"),
            prebuild: binariesDir.appendingPathComponent("xcprebuild"),
            postbuild: binariesDir.appendingPathComponent("xcpostbuild")
        )
        self.buildSettingsAppenderOptions = buildSettingsAppenderOptions
    }
}
