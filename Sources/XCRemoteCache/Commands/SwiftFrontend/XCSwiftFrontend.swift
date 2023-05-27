// Copyright (c) 2023 Spotify AB.
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

enum SwiftFrontendArgInputError: Error {
    // swift-frontend should either be compling or emiting a module
    case bothCompilationAndEmitAction
    // no .swift files have been passed as input files
    case noCompilationInputs
    // no -primary-file .swift files have been passed as input files
    case noPrimaryFileCompilationInputs
    // number of -emit-dependencies-path doesn't match compilation inputs
    case dependenciesOuputCountDoesntMatch(expected: Int, parsed: Int)
    // number of -serialize-diagnostics-path doesn't match compilation inputs
    case diagnosticsOuputCountDoesntMatch(expected: Int, parsed: Int)
    // number of -o doesn't match compilation inputs
    case outputsOuputCountDoesntMatch(expected: Int, parsed: Int)
    // number of -o for emit-module can be only 1
    case emitModulOuputCountIsNot1(parsed: Int)
    // number of -emit-dependencies-path for emit-module can be 0 or 1 (generate or not)
    case emitModuleDependenciesOuputCountIsHigherThan1(parsed: Int)
    // number of -serialize-diagnostics-path for emit-module can be 0 or 1 (generate or not)
    case emitModuleDiagnosticsOuputCountIsHigherThan1(parsed: Int)
    // emit-module requires -emit-objc-header-path
    case emitModuleMissingObjcHeaderPath
    // -target is required
    case emitMissingTarget
    // -moduleName is required
    case emiMissingModuleName
}

public struct SwiftFrontendArgInput {
    let compile: Bool
    let emitModule: Bool
    let objcHeaderOutput: String?
    let moduleName: String?
    let target: String?
    let primaryInputPaths: [String]
    let inputPaths: [String]
    var outputPaths: [String]
    var dependenciesPaths: [String]
    // Extra params
    // Diagnostics are not supported yet in the XCRemoteCache (cached artifacts assumes no warnings)
    var diagnosticsPaths: [String]
    // Unsed for now:
    // .swiftsourceinfo and .swiftdoc will be placed next to the .swiftmodule
    let sourceInfoPath: String?
    let docPath: String?

    /// Manual initializer implementation required to be public
    public init(
        compile: Bool,
        emitModule: Bool,
        objcHeaderOutput: String?,
        moduleName: String?,
        target: String?,
        primaryInputPaths: [String],
        inputPaths: [String],
        outputPaths: [String],
        dependenciesPaths: [String],
        diagnosticsPaths: [String],
        sourceInfoPath: String?,
        docPath: String?
    ) {
        self.compile = compile
        self.emitModule = emitModule
        self.objcHeaderOutput = objcHeaderOutput
        self.moduleName = moduleName
        self.target = target
        self.primaryInputPaths = primaryInputPaths
        self.inputPaths = inputPaths
        self.outputPaths = outputPaths
        self.dependenciesPaths = dependenciesPaths
        self.diagnosticsPaths = diagnosticsPaths
        self.sourceInfoPath = sourceInfoPath
        self.docPath = docPath
    }

    /// An early validation of the swift-frontend args
    /// Returns false an error, if the mode is not supported
    /// and the fallback to the undelying command should be executed
    public func validate() throws {
        guard compile != emitModule else {
            throw SwiftFrontendArgInputError.bothCompilationAndEmitAction
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func generateSwiftcContext(config: XCRemoteCacheConfig) throws -> SwiftcContext {
        let inputPathsCount = inputPaths.count
        let primaryInputsCount = primaryInputPaths.count
        guard inputPathsCount > 0 else {
            throw SwiftFrontendArgInputError.noCompilationInputs
        }
        guard let target = target else {
            throw SwiftFrontendArgInputError.emitMissingTarget
        }
        guard let moduleName = moduleName else {
            throw SwiftFrontendArgInputError.emiMissingModuleName
        }

        if compile {
            guard primaryInputsCount > 0 else {
                throw SwiftFrontendArgInputError.noPrimaryFileCompilationInputs
            }
            guard [primaryInputsCount, 0].contains(dependenciesPaths.count) else {
                throw SwiftFrontendArgInputError.dependenciesOuputCountDoesntMatch(
                    expected: inputPathsCount,
                    parsed: dependenciesPaths.count
                )
            }
            guard [primaryInputsCount, 0].contains(diagnosticsPaths.count) else {
                throw SwiftFrontendArgInputError.diagnosticsOuputCountDoesntMatch(
                    expected: inputPathsCount,
                    parsed: diagnosticsPaths.count
                )
            }
            guard outputPaths.count == primaryInputsCount else {
                throw SwiftFrontendArgInputError.outputsOuputCountDoesntMatch(
                    expected: inputPathsCount,
                    parsed: outputPaths.count
                )
            }
            let primaryInputFilesURLs: [URL] = primaryInputPaths.map(URL.init(fileURLWithPath:))

            let steps: SwiftcContext.SwiftcSteps = SwiftcContext.SwiftcSteps(
                compileFilesScope: .subset(primaryInputFilesURLs),
                emitModule: nil
            )

            let compilationFileMap = (0..<primaryInputsCount).reduce([String: SwiftFileCompilationInfo]()) { prev, i in
                var new = prev
                new[primaryInputPaths[i]] = SwiftFileCompilationInfo(
                    file: primaryInputFilesURLs[i],
                    dependencies: dependenciesPaths.get(i).map(URL.init(fileURLWithPath:)),
                    object: outputPaths.get(i).map(URL.init(fileURLWithPath:)),
                    swiftDependencies: dependenciesPaths.get(i).map(URL.init(fileURLWithPath:))
                )
                return new
            }

            return try .init(
                config: config,
                moduleName: moduleName,
                steps: steps,
                outputs: .map(compilationFileMap),
                target: target,
                inputs: .list(outputPaths),
                exampleWorkspaceFilePath: outputPaths[0]
            )
        } else {
            guard outputPaths.count == 1 else {
                throw SwiftFrontendArgInputError.emitModulOuputCountIsNot1(parsed: outputPaths.count)
            }
            guard let objcHeaderOutput = objcHeaderOutput else {
                throw SwiftFrontendArgInputError.emitModuleMissingObjcHeaderPath
            }
            guard diagnosticsPaths.count <= 1 else {
                throw SwiftFrontendArgInputError.emitModuleDiagnosticsOuputCountIsHigherThan1(
                    parsed: diagnosticsPaths.count
                )
            }
            guard dependenciesPaths.count <= 1 else {
                throw SwiftFrontendArgInputError.emitModuleDependenciesOuputCountIsHigherThan1(
                    parsed: dependenciesPaths.count
                )
            }
            guard diagnosticsPaths.count <= 1 else {
                throw SwiftFrontendArgInputError.emitModuleDiagnosticsOuputCountIsHigherThan1(
                    parsed: diagnosticsPaths.count
                )
            }
            let steps: SwiftcContext.SwiftcSteps = SwiftcContext.SwiftcSteps(
                compileFilesScope: .none,
                emitModule: SwiftcContext.SwiftcStepEmitModule(
                    objcHeaderOutput: URL(fileURLWithPath: objcHeaderOutput),
                    modulePathOutput: URL(fileURLWithPath: outputPaths[0])
                )
            )
            return try .init(
                config: config,
                moduleName: moduleName,
                steps: steps,
                outputs: .map([:]),
                target: target,
                inputs: .list([]),
                exampleWorkspaceFilePath: objcHeaderOutput
            )
        }
    }
}

public class XCSwiftFrontend: XCSwiftAbstract<SwiftFrontendArgInput> {
    // don't lock individual compilation invocations for more than 10s
    private static let MaxLockingTimeout: TimeInterval = 10
    private let env: [String: String]

    public init(
        command: String,
        inputArgs: SwiftFrontendArgInput,
        env: [String: String],
        dependenciesWriter: @escaping (URL, FileManager) -> DependenciesWriter,
        touchFactory: @escaping (URL, FileManager) -> Touch
    ) throws {
        self.env = env
        super.init(
            command: command,
            inputArgs: inputArgs,
            dependenciesWriter: dependenciesWriter,
            touchFactory: touchFactory
        )
    }

    override func buildContext() -> (XCRemoteCacheConfig, SwiftcContext) {
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: SwiftcContext

        do {
            let srcRoot: URL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            config = try XCRemoteCacheConfigReader(srcRootPath: srcRoot.path, fileReader: fileManager)
                .readConfiguration()
            context = try SwiftcContext(config: config, input: inputArgs)
        } catch {
            exit(1, "FATAL: XCSwiftFrontend initialization failed with error: \(error)")
        }
        // do not cache this context, as it is subject to change when
        // the emit-module finds that the cached artifact cannot be used
        return (config, context)
    }

    override public func run() throws {
        do {
            /// The LLBUILD_BUILD_ID ENV that describes the swiftc (parent) invocation
            let llbuildId: String = try env.readEnv(key: "LLBUILD_BUILD_ID")
            let (_, context) = buildContext()

            let sharedLockFileURL = XCSwiftFrontend.generateLlbuildIdSharedLock(llbuildId: llbuildId, tmpDir: context.tempDir)
            let sharedLock = ExclusiveFile(sharedLockFileURL, mode: .override)

            let action: CommonSwiftFrontendOrchestrator.Action = inputArgs.emitModule ? .emitModule : .compile
            let swiftFrontendOrchestrator = CommonSwiftFrontendOrchestrator(
                mode: context.mode,
                action: action,
                lockAccessor: sharedLock,
                maxLockTimeout: Self.self.MaxLockingTimeout
            )

            try swiftFrontendOrchestrator.run(criticalSection: super.run)
        } catch {
            defaultLog("Cannot correctly orchestrate the \(command) with params \(inputArgs): error: \(error)")
            throw error
        }
    }
}

extension XCSwiftFrontend {
    /// The file is used to sycnhronize mutliple swift-frontend invocations
    static func generateLlbuildIdSharedLock(llbuildId: String, tmpDir: URL) -> URL {
        return tmpDir.appendingPathComponent(llbuildId).appendingPathExtension("lock")
    }
}
