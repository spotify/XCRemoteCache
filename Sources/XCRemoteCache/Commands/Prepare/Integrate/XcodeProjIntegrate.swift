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
import PathKit
import XcodeProj
import Yams

enum XcodeProjIntegrateError: Error {
    /// Thrown when backend server doesn't contain a commit sha with all artifacts ready
    case noArtifactsToReuse
}

/// Integrates XCRemoteCache using third-party XcodeProj library
struct XcodeProjIntegrate: Integrate {
    fileprivate static let BuildStepPrefix = "[RC] "

    // IntegrationConfiguration represents a subset of the XCRemoteCacheConfig configuration
    private struct IntegrationCacheConfig: Encodable {
        let recommendedCacheAddress: URL?
        let xcccFile: String
        let mode: Mode

        enum CodingKeys: String, CodingKey {
            case xcccFile = "xccc_file"
            case recommendedCacheAddress = "recommended_cache_address"
            case mode
        }
    }

    private let projectURL: URL
    private let mode: Mode
    private let binaries: XCRCBinariesPaths
    private let configurationIncludeOracle: IncludeOracle
    private let targetIncludeOracle: IncludeOracle
    private let finalProducerTarget: String?
    private let buildSettingsAppender: BuildSettingsIntegrateAppender
    private let consumerEligibleConfigurations: [String]
    private let consumerEligiblePlatforms: [String]
    private let prebuildPhase: PBXShellScriptBuildPhase
    private let postbuildPhase: PBXShellScriptBuildPhase
    private let markPhase: PBXShellScriptBuildPhase
    private let configOverride: URL
    private let lldbPatcher: LLDBInitPatcher
    private let output: URL?

    init(
        project: URL,
        mode: Mode,
        binaries: XCRCBinariesPaths,
        configurationIncludeOracle: IncludeOracle,
        targetIncludeOracle: IncludeOracle,
        finalProducerTarget: String?,
        buildSettingsAppender: BuildSettingsIntegrateAppender,
        consumerEligibleConfigurations: [String],
        consumerEligiblePlatforms: [String],
        configOverride: URL,
        lldbPatcher: LLDBInitPatcher,
        output: URL?
    ) {
        projectURL = project
        self.mode = mode
        self.binaries = binaries
        self.configurationIncludeOracle = configurationIncludeOracle
        self.targetIncludeOracle = targetIncludeOracle
        self.finalProducerTarget = finalProducerTarget
        self.buildSettingsAppender = buildSettingsAppender
        self.consumerEligibleConfigurations = consumerEligibleConfigurations
        self.consumerEligiblePlatforms = consumerEligiblePlatforms
        self.configOverride = configOverride
        self.lldbPatcher = lldbPatcher
        self.output = output

        prebuildPhase = PBXShellScriptBuildPhase(
            name: "\(Self.BuildStepPrefix)RemoteCache_prebuild",
            inputPaths: [binaries.prebuild.path],
            outputPaths: ["$(TARGET_TEMP_DIR)/rc.enabled"],
            shellScript: "\"$SCRIPT_INPUT_FILE_0\"",
            dependencyFile: "$(TARGET_TEMP_DIR)/prebuild.d"
        )
        postbuildPhase = PBXShellScriptBuildPhase(
            name: "\(Self.BuildStepPrefix)RemoteCache_postbuild",
            inputPaths: [binaries.postbuild.path],
            outputPaths: [
                """
                $(TARGET_BUILD_DIR)/$(MODULES_FOLDER_PATH)/$(PRODUCT_MODULE_NAME).swiftmodule/\
                $(XCRC_PLATFORM_PREFERRED_ARCH).swiftmodule.md5
                """,
                """
                $(TARGET_BUILD_DIR)/$(MODULES_FOLDER_PATH)/$(PRODUCT_MODULE_NAME).swiftmodule/\
                $(XCRC_PLATFORM_PREFERRED_ARCH)-$(LLVM_TARGET_TRIPLE_VENDOR)-$(SWIFT_PLATFORM_TARGET_PREFIX)\
                $(LLVM_TARGET_TRIPLE_SUFFIX).swiftmodule.md5
                """,
            ],
            shellScript: "\"$SCRIPT_INPUT_FILE_0\"",
            dependencyFile: "$(TARGET_TEMP_DIR)/postbuild.d"
        )
        markPhase = PBXShellScriptBuildPhase(
            name: "\(Self.BuildStepPrefix)RemoteCache_mark",
            inputPaths: [binaries.prepare.path],
            shellScript:
                "\"$SCRIPT_INPUT_FILE_0\" mark " +
                "--configuration \"$CONFIGURATION\" --platform \"$PLATFORM_NAME\""
        )
    }

    /// Dump overrides to the XCRemoteCacheConfig into disk location
    private func storeRCOverride(
        _ override: IntegrationCacheConfig,
        configOverrideLocation: URL
    ) throws {
        // Store .rcinfo override
        let encoder = YAMLEncoder()
        let encodedYAML = try encoder.encode(override)
        try encodedYAML.write(to: configOverrideLocation, atomically: false, encoding: .utf8)
    }

    // swiftlint:disable:next function_body_length
    func run() throws {
        let outputFile = output ?? projectURL
        let projectRoot = projectURL.deletingLastPathComponent()

        let projectPath = Path(projectURL.path)
        let outputPath = Path(outputFile.path)

        // Override all extra configs (default to 'user.rc', next to the main '.rcinfo' file)
        let initialOverride = IntegrationCacheConfig(
            recommendedCacheAddress: nil,
            xcccFile: binaries.cc.path,
            mode: mode
        )
        try storeRCOverride(initialOverride, configOverrideLocation: configOverride)

        if case .consumer = mode {
            // require successful preparation
            do {

                // Call xcprepare to probe if XCRemoteCache can be safely used
                let args = ["--configuration"] + consumerEligibleConfigurations + ["--platform"] +
                    consumerEligiblePlatforms
                let yamlString = try shellGetStdout(
                    binaries.prepare.path,
                    args: args,
                    inDir: projectRoot.path,
                    environment: nil
                )
                let decoder = YAMLDecoder()
                let prepareResult = try decoder.decode(PrepareResult.self, from: yamlString, userInfo: [:])
                guard case .preparedFor(_, recommendedCacheAddress: let remote) = prepareResult else {
                    throw XcodeProjIntegrateError.noArtifactsToReuse
                }

                // Override the configuration again to include recommended cache address provided by xcprepare
                let finalOverride = IntegrationCacheConfig(
                    recommendedCacheAddress: remote,
                    xcccFile: binaries.cc.path,
                    mode: mode
                )
                try storeRCOverride(finalOverride, configOverrideLocation: configOverride)
            } catch {
                // integration cannot be done as `xccc` hasn't been generated
                exit(1, "XCRemoteCache cannot be initialized with a consumer mode. Error: \(error).")
            }
        }

        // modify .pbxproj
        let xcodeproj = try XcodeProj(path: projectPath)

        for target in xcodeproj.pbxproj.nativeTargets {
            guard targetIncludeOracle.shouldInclude(identifier: target.name) else {
                continue
            }
            guard let targetConfigurations = target.buildConfigurationList else {
                fatalError("Missing buildConfigurationList. Cannot apply")
            }

            // Apply settings for only few configurations
            let targetConfigurationsToIntegrate = targetConfigurations.buildConfigurations.filter {
                configurationIncludeOracle.shouldInclude(identifier: $0.name)
            }

            guard !targetConfigurationsToIntegrate.isEmpty else {
                // No need to append build phases if none of Configurations exist for that target
                continue
            }

            for buildConfiguration in targetConfigurationsToIntegrate {
                let initialSettings = buildConfiguration.buildSettings
                let finalSettings = buildSettingsAppender.appendToBuildSettings(
                    buildSettings: initialSettings,
                    wrappers: binaries
                )
                buildConfiguration.buildSettings = finalSettings
            }

            addSharedBuildPhases(target: target, in: xcodeproj.pbxproj)
            // Add producer build phase that marks given sha+configuration+platform as "ready to use"
            if case .producer = mode, finalProducerTarget == target.name {
                addFinalProducerBuildPhases(target: target, in: xcodeproj.pbxproj)
            }
        }

        try xcodeproj.write(path: outputPath)

        try lldbPatcher.enable()
    }

    /// Adds build phases for both producer and consumer
    private func addSharedBuildPhases(target: PBXNativeTarget, in pbxproj: PBXProj) {
        // delete all previous XCRC build phases
        let previousRCPhases = target.buildPhases.filter(isRCPhase)
        target.buildPhases.removeAll(where: previousRCPhases.contains)

        if let sourceIndex = target.buildPhases.map(\.buildPhase).firstIndex(of: .sources) {
            // add (pre|post)build phases only when a target has some compilation steps
            // otherwise they make no sense (nothing to store in an artifact)
            pbxproj.add(object: prebuildPhase)
            target.buildPhases.insert(prebuildPhase, at: sourceIndex)
            pbxproj.add(object: postbuildPhase)
            target.buildPhases.append(postbuildPhase)
        }
    }

    /// Adds build phases as the very last producer target
    private func addFinalProducerBuildPhases(target: PBXNativeTarget, in pbxproj: PBXProj) {
        pbxproj.add(object: markPhase)
        target.buildPhases.append(markPhase)
    }

    private func isRCPhase(_ phase: PBXBuildPhase) -> Bool {
        phase.name()?.hasPrefix(Self.BuildStepPrefix) == true
    }
}
