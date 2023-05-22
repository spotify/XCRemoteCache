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

struct SwiftFrontendEmitModuleInfo: Equatable {
    let inputs: [URL]
    let objcHeader: URL
    let diagnostics: URL?
    let dependencies: URL?
    let output: URL
    let target: String
    let moduleName: String
    let sourceInfo: URL?
    let doc: URL?
}

struct SwiftFrontendCompilationInfo: Equatable {
    let target: String
    let moduleName: String
}

enum SwiftFrontendAction {
    case emitModule(emitModuleInfo: SwiftFrontendEmitModuleInfo, inputFiles: [URL])
    case compile(compilationInfo: SwiftFrontendCompilationInfo, compilationFiles: [SwiftFileCompilationInfo])
}

extension SwiftFrontendAction {
    var tmpDir: URL {
        // modulePathOutput is place in $TARGET_TEMP_DIR/Objects-normal/$ARCH/$TARGET_NAME.swiftmodule
        // That may be subject to change for other Xcode versions (or other variants)
        return outputWorkspaceDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
    var arch: String {
        return outputWorkspaceDir.deletingLastPathComponent().lastPathComponent
    }
    
    var target: String {
        switch self {
        case .emitModule(emitModuleInfo: let info, inputFiles: _):
            return info.target
        case .compile(compilationInfo: let info, compilationFiles: _):
            return info.target
        }
    }
    
    var moduleName: String {
        switch self {
        case .emitModule(emitModuleInfo: let info, inputFiles: _):
            return info.moduleName
        case .compile(compilationInfo: let info, compilationFiles: _):
            return info.moduleName
        }
    }
    
    
    // The workspace where Xcode asks to put all compilation-relates
    // files (like .d or .swiftmodule)
    // This location is used to infere the tmpDir and arch
    private var outputWorkspaceDir: URL {
        switch self {
        case .emitModule(emitModuleInfo: let info, inputFiles: _):
            return info.output
        case .compile(_, let files):
            // if invoked compilation via swift-frontend, the .d file is always defined
            return files[0].dependencies!
        }
    }
}


enum SwiftFrontendArgInputError: Error {
    // swift-frontend should either be compling or emiting a module
    case bothCompilationAndEmitAction
    // no .swift files have been passed as input files
    case noCompilationInputs
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
    let inputPaths: [String]
    var outputPaths: [String]
    var dependenciesPaths: [String]
    var diagnosticsPaths: [String]
    let sourceInfoPath: String?
    let docPath: String?

    /// Manual initializer implementation required to be public
    public init(compile: Bool, emitModule: Bool, objcHeaderOutput: String?, moduleName: String?, target: String?, inputPaths: [String], outputPaths: [String], dependenciesPaths: [String], diagnosticsPaths: [String],
                sourceInfoPath: String?, docPath: String?) {
        self.compile = compile
        self.emitModule = emitModule
        self.objcHeaderOutput = objcHeaderOutput
        self.moduleName = moduleName
        self.target = target
        self.inputPaths = inputPaths
        self.outputPaths = outputPaths
        self.dependenciesPaths = dependenciesPaths
        self.diagnosticsPaths = diagnosticsPaths
        self.sourceInfoPath = sourceInfoPath
        self.docPath = docPath
    }
    
    func generateAction() throws -> SwiftFrontendAction {
        guard compile != emitModule else {
            throw SwiftFrontendArgInputError.bothCompilationAndEmitAction
        }
        let inputPathsCount = inputPaths.count
        guard inputPathsCount > 0 else {
            throw SwiftFrontendArgInputError.noCompilationInputs
        }
        guard let target = target else {
            throw SwiftFrontendArgInputError.emitMissingTarget
        }
        guard let moduleName = moduleName else {
            throw SwiftFrontendArgInputError.emiMissingModuleName
        }
        let inputURLs: [URL] = inputPaths.map(URL.init(fileURLWithPath:))
        
        if compile {
            guard [inputPathsCount, 0].contains(dependenciesPaths.count) else {
                throw SwiftFrontendArgInputError.dependenciesOuputCountDoesntMatch(expected: inputPathsCount, parsed: dependenciesPaths.count)
            }
            guard [inputPathsCount, 0].contains(diagnosticsPaths.count) else {
                throw SwiftFrontendArgInputError.diagnosticsOuputCountDoesntMatch(expected: inputPathsCount, parsed: diagnosticsPaths.count)
            }
            guard outputPaths.count == inputPathsCount else {
                throw SwiftFrontendArgInputError.outputsOuputCountDoesntMatch(expected: inputPathsCount, parsed: outputPaths.count)
            }
            let compilationFileInfos: [SwiftFileCompilationInfo] = (0..<inputPathsCount).map { i in
                return SwiftFileCompilationInfo(
                    file: inputURLs[i],
                    dependencies: dependenciesPaths.first.map(URL.init(fileURLWithPath:)),
                    object: outputPaths.first.map(URL.init(fileURLWithPath:)),
                    swiftDependencies: dependenciesPaths.first.map(URL.init(fileURLWithPath:))
                )
            }
            let compilationInfo = SwiftFrontendCompilationInfo(target: target, moduleName: moduleName)
            return .compile(compilationInfo: compilationInfo, compilationFiles: compilationFileInfos)
        } else {
            guard outputPaths.count == 1 else {
                throw SwiftFrontendArgInputError.emitModulOuputCountIsNot1(parsed: outputPaths.count)
            }
            guard let objcHeaderOutput = objcHeaderOutput else {
                throw SwiftFrontendArgInputError.emitModuleMissingObjcHeaderPath
            }
            guard diagnosticsPaths.count <= 1 else {
                throw SwiftFrontendArgInputError.emitModuleDiagnosticsOuputCountIsHigherThan1(parsed: diagnosticsPaths.count)
            }
            guard dependenciesPaths.count <= 1 else {
                throw SwiftFrontendArgInputError.emitModuleDependenciesOuputCountIsHigherThan1(parsed: dependenciesPaths.count)
            }
            guard diagnosticsPaths.count <= 1 else {
                throw SwiftFrontendArgInputError.emitModuleDiagnosticsOuputCountIsHigherThan1(parsed: diagnosticsPaths.count)
            }
            let moduleInfo: SwiftFrontendEmitModuleInfo = SwiftFrontendEmitModuleInfo(
                inputs: inputURLs,
                objcHeader: URL.init(fileURLWithPath: objcHeaderOutput),
                diagnostics: diagnosticsPaths.first.map(URL.init(fileURLWithPath:)),
                dependencies: dependenciesPaths.first.map(URL.init(fileURLWithPath:)),
                output: URL.init(fileURLWithPath: outputPaths[0]),
                target: target,
                moduleName: moduleName,
                sourceInfo: sourceInfoPath.map(URL.init(fileURLWithPath:)),
                doc: docPath.map(URL.init(fileURLWithPath:))
            )
            return .emitModule(emitModuleInfo: moduleInfo, inputFiles: inputURLs)
        }
    }
}

public class XCSwiftFrontend {
    private let command: String
    // raw representation of args in the "string" domain
    private let inputArgs: SwiftFrontendArgInput
    private let env: [String: String]
    // validated and frontend action
    private let action: SwiftFrontendAction
    private let dependenciesWriterFactory: (URL, FileManager) -> DependenciesWriter
    private let touchFactory: (URL, FileManager) -> Touch

    public init(
        command: String,
        inputArgs: SwiftFrontendArgInput,
        env: [String: String],
        dependenciesWriter: @escaping (URL, FileManager) -> DependenciesWriter,
        touchFactory: @escaping (URL, FileManager) -> Touch
    ) throws {
        self.command = command
        self.inputArgs = inputArgs
        self.env = env
        dependenciesWriterFactory = dependenciesWriter
        self.touchFactory = touchFactory
        
        self.action = try inputArgs.generateAction()
    }

    // swiftlint:disable:next function_body_length
    public func run() {
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: SwiftFrontendContext
        
        do {
            let srcRoot: URL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            config = try XCRemoteCacheConfigReader(srcRootPath: srcRoot.path, fileReader: fileManager)
                .readConfiguration()
            context = try SwiftFrontendContext(config: config, env: env, input: inputArgs, action: action)
        } catch {
            exit(1, "FATAL: XCSwiftFrontend initialization failed with error: \(error)")
        }
        
        
        let swiftFrontendCommand = config.swiftFrontendCommand
        let markerURL = context.tempDir.appendingPathComponent(config.modeMarkerPath)
        
        
        let markerReader = FileMarkerReader(markerURL, fileManager: fileManager)
        let markerWriter = FileMarkerWriter(markerURL, fileAccessor: fileManager)

        
//        let inputReader = SwiftcFilemapInputEditor(context.filemap, fileManager: fileManager)
//        let fileListEditor = FileListEditor(context.fileList, fileManager: fileManager)
        let artifactOrganizer = ZipArtifactOrganizer(
            targetTempDir: context.tempDir,
            // xcswiftc  doesn't call artifact preprocessing
            artifactProcessors: [],
            fileManager: fileManager
        )
        // TODO: check for allowedFile comparing a list of all inputfiles, not dependencies from a marker
        let makerReferencedFilesListScanner = FileListScannerImpl(markerReader, caseSensitive: false)
        let allowedFilesListScanner = ExceptionsFilteredFileListScanner(
            allowedFilenames: ["\(config.thinTargetMockFilename).swift"],
            disallowedFilenames: [],
            scanner: makerReferencedFilesListScanner
        )
        let artifactBuilder: ArtifactSwiftProductsBuilder = ArtifactSwiftProductsBuilderImpl(
            workingDir: context.tempDir,
            moduleName: context.moduleName,
            fileManager: fileManager
        )
        let productsGenerator = DiskSwiftFrontendProductsGenerator(
            action: action,
            diskCopier: HardLinkDiskCopier(fileManager: fileManager)
        )
        let allInvocationsStorage = ExistingFileStorage(
            storageFile: context.invocationHistoryFile,
            command: swiftFrontendCommand
        )
        // When fallbacking to local compilation do not call historical `swiftc` invocations
        // The current fallback invocation already compiles all files in a target
        let invocationStorage = FilteredInvocationStorage(
            storage: allInvocationsStorage,
            retrieveIgnoredCommands: [swiftFrontendCommand]
        )
        let shellOut = ProcessShellOut()

        let swiftFrontend = SwiftFrontend(
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: fileManager,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )
        /*let orchestrator = SwiftcOrchestrator(
            mode: context.mode,
            swiftc: swiftc,
            swiftcCommand: swiftcCommand,
            objcHeaderOutput: context.objcHeaderOutput,
            moduleOutput: context.modulePathOutput,
            arch: context.arch,
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOut
        )
        do {
            try orchestrator.run()
        } catch {
            exit(1, "Swiftc failed with error: \(error)")
        }
         */
    }
}
