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

public struct SwiftcArgInput {
    let objcHeaderOutput: String
    let moduleName: String
    let modulePathOutput: String
    let filemap: String
    let target: String
    let fileList: String

    /// Manual initializer implementation required to be public
    public init(
        objcHeaderOutput: String,
        moduleName: String,
        modulePathOutput: String,
        filemap: String,
        target: String,
        fileList: String
    ) {
        self.objcHeaderOutput = objcHeaderOutput
        self.moduleName = moduleName
        self.modulePathOutput = modulePathOutput
        self.filemap = filemap
        self.target = target
        self.fileList = fileList
    }
}

public class XCSwiftAbstract<InputArgs> {
    let command: String
    let inputArgs: InputArgs
    private let dependenciesWriterFactory: (URL, FileManager) -> DependenciesWriter
    private let touchFactory: (URL, FileManager) -> Touch

    public init(
        command: String,
        inputArgs: InputArgs,
        dependenciesWriter: @escaping (URL, FileManager) -> DependenciesWriter,
        touchFactory: @escaping (URL, FileManager) -> Touch
    ) {
        self.command = command
        self.inputArgs = inputArgs
        dependenciesWriterFactory = dependenciesWriter
        self.touchFactory = touchFactory
    }

    func buildContext() throws -> (XCRemoteCacheConfig, SwiftcContext) {
        fatalError("Need to override in \(Self.self)")
    }

    // Return the fallback command that should be invoked in case of a cache miss
    // Expected that swift-frontend invokcations will override it
    func fallbackCommand(config: XCRemoteCacheConfig) throws -> String {
        config.swiftcCommand
    }

    // swiftlint:disable:next function_body_length
    public func run() throws {
        let fileManager = FileManager.default
        let (config, context) = try buildContext()

        let swiftcCommand = try fallbackCommand(config: config)
        let markerURL = context.tempDir.appendingPathComponent(config.modeMarkerPath)
        let markerReader = FileMarkerReader(markerURL, fileManager: fileManager)
        let markerWriter = FileMarkerWriter(markerURL, fileAccessor: fileManager)

        let inputReader: SwiftcInputReader
        switch context.inputs {
        case .fileMap(let path):
            inputReader = SwiftcFilemapInputEditor(
                URL(fileURLWithPath: path),
                fileFormat: .json,
                fileManager: fileManager
            )
        case .supplementaryFileMap(let path):
            // Supplementary file map is endoded in the yaml file (contraty to
            // the standard filemap, which is in json)
            inputReader = SwiftcFilemapInputEditor(
                URL(fileURLWithPath: path),
                fileFormat: .yaml,
                fileManager: fileManager
            )
        case .map(let map):
            // static - passed via the arguments list
            inputReader = StaticSwiftcInputReader(
                moduleDependencies: context.steps.emitModule?.dependencies,
                // with Xcode 14, inputs via cmd are only used for compilations
                swiftDependencies: nil,
                compilationFiles: Array(map.values)
            )
        }
        let fileListReader: ListReader
        switch context.compilationFiles {
        case .fileList(let path):
            fileListReader = FileListEditor(URL(fileURLWithPath: path), fileManager: fileManager)
        case .list(let paths):
            fileListReader = StaticFileListReader(list: paths.map(URL.init(fileURLWithPath:)))
        }
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
        let productsGenerator: SwiftcProductsGenerator
        if let emitModule = context.steps.emitModule {
            productsGenerator = DiskSwiftcProductsGenerator(
                modulePathOutput: emitModule.modulePathOutput,
                objcHeaderOutput: emitModule.objcHeaderOutput,
                diskCopier: HardLinkDiskCopier(fileManager: fileManager)
            )
        } else {
            // If the module was not requested for this proces (compiling files only)
            // do nothing, when someone (e.g. a plugin) asks for the products generation
            // This generation will happend in a separate process, where the module
            // generation is requested
            productsGenerator = NoopSwiftcProductsGenerator()
        }
        let allInvocationsStorage = ExistingFileStorage(
            storageFile: context.invocationHistoryFile,
            command: swiftcCommand
        )
        // When fallbacking to local compilation do not call historical `swiftc` invocations
        // The current fallback invocation already compiles all files in a target
        let invocationStorage = FilteredInvocationStorage(
            storage: allInvocationsStorage,
            retrieveIgnoredCommands: [swiftcCommand]
        )
        let shellOut = ProcessShellOut()

        let swiftc = Swiftc(
            inputFileListReader: fileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: inputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: fileManager,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )
        let orchestrator = SwiftcOrchestrator(
            mode: context.mode,
            swiftc: swiftc,
            swiftcCommand: swiftcCommand,
            objcHeaderOutput: context.steps.emitModule?.objcHeaderOutput,
            moduleOutput: context.steps.emitModule?.modulePathOutput,
            arch: context.arch,
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOut
        )
        try orchestrator.run()
    }
}

public class XCSwiftc: XCSwiftAbstract<SwiftcArgInput> {
    override func buildContext() throws -> (XCRemoteCacheConfig, SwiftcContext) {
        let fileReader = FileManager.default
        let config: XCRemoteCacheConfig
        let context: SwiftcContext
        let srcRoot: URL = URL(fileURLWithPath: fileReader.currentDirectoryPath)
        config = try XCRemoteCacheConfigReader(srcRootPath: srcRoot.path, fileReader: fileReader)
            .readConfiguration()
        context = try SwiftcContext(config: config, input: inputArgs)

        return (config, context)
    }
}
