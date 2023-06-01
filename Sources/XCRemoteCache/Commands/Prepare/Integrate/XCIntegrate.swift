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

public class XCIntegrate {
    /// Separator of sequential command line arguments (e.g. configurations to exclude)
    fileprivate static let inputSeparate: Character = ","

    private let projectPath: String
    private let mode: Mode
    private let configurationsExclude: String
    private let configurationsInclude: String
    private let targetsExclude: String
    private let targetsInclude: String
    private let finalProducerTarget: String?
    private let consumerEligibleConfigurations: String
    private let consumerEligiblePlatforms: String
    private let lldbMode: LLDBInitMode
    private let fakeSrcRoot: String
    private let sdksExclude: String
    private let output: String?

    public init(
        input: String,
        mode: Mode,
        configurationsExclude: String,
        configurationsInclude: String,
        targetsExclude: String,
        targetsInclude: String,
        finalProducerTarget: String?,
        consumerEligibleConfigurations: String,
        consumerEligiblePlatforms: String,
        lldbMode: LLDBInitMode,
        fakeSrcRoot: String,
        sdksExclude: String,
        output: String?
    ) {
        projectPath = input
        self.mode = mode
        self.configurationsExclude = configurationsExclude
        self.configurationsInclude = configurationsInclude
        self.targetsExclude = targetsExclude
        self.targetsInclude = targetsInclude
        self.finalProducerTarget = finalProducerTarget
        self.consumerEligibleConfigurations = consumerEligibleConfigurations
        self.consumerEligiblePlatforms = consumerEligiblePlatforms
        self.lldbMode = lldbMode
        self.fakeSrcRoot = fakeSrcRoot
        self.sdksExclude = sdksExclude
        self.output = output
    }

    // swiftlint:disable:next function_body_length
    public func main() {
        do {
            let env = ProcessInfo.processInfo.environment
            let fileManager = FileManager.default
            let commandURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
            // All binaries (xcprepare, xcprebuild etc.) should be placed next to each other
            let binariesDir = commandURL.deletingLastPathComponent()

            let srcRoot: URL = URL(fileURLWithPath: projectPath).deletingLastPathComponent()
            let config = try XCRemoteCacheConfigReader(srcRootPath: srcRoot.path, fileReader: fileManager)
                .readConfiguration()

            let context = try IntegrateContext(
                input: projectPath,
                config: config,
                mode: mode,
                env: env,
                binariesDir: binariesDir,
                fakeSrcRoot: fakeSrcRoot,
                outputPath: output
            )
            let configurationOracle = IncludeExcludeOracle(
                excludes: configurationsExclude.integrateArrayArguments,
                includes: configurationsInclude.integrateArrayArguments
            )
            let targetOracle = IncludeExcludeOracle(
                excludes: targetsExclude.integrateArrayArguments,
                includes: targetsInclude.integrateArrayArguments
            )
            let buildSettingsAppender = XcodeProjBuildSettingsIntegrateAppender(
                mode: context.mode,
                repoRoot: context.repoRoot,
                fakeSrcRoot: context.fakeSrcRoot,
                sdksExclude: sdksExclude.integrateArrayArguments,
                options: context.buildSettingsAppenderOptions
            )
            let lldbPatcher: LLDBInitPatcher
            switch lldbMode {
            case .none:
                lldbPatcher = NoopLLDBInitPatcher()
            case .user:
                let lldbInitFile = URL(fileURLWithPath: "~/.lldbinit".expandingTildeInPath)
                lldbPatcher = FileLLDBInitPatcher(
                    file: lldbInitFile,
                    rootURL: context.repoRoot,
                    fakeSrcRoot: context.fakeSrcRoot,
                    fileAccessor: fileManager
                )
            }

            let integrator = XcodeProjIntegrate(
                project: context.projectPath,
                mode: context.mode,
                binaries: context.binaries,
                configurationIncludeOracle: configurationOracle,
                targetIncludeOracle: targetOracle,
                finalProducerTarget: finalProducerTarget,
                buildSettingsAppender: buildSettingsAppender,
                consumerEligibleConfigurations: consumerEligibleConfigurations.integrateArrayArguments,
                consumerEligiblePlatforms: consumerEligiblePlatforms.integrateArrayArguments,
                configOverride: context.configOverride,
                lldbPatcher: lldbPatcher,
                output: context.output
            )
            try integrator.run()
        } catch {
            // XCIntegrate has no fallback
            exit(1, "FATAL: Integrate initialization failed with error: \(error)")
        }
    }
}

private extension String {
    var integrateArrayArguments: [String] {
        split(separator: XCIntegrate.inputSeparate).map(String.init)
    }
}
