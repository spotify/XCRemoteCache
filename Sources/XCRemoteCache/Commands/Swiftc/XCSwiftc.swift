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

public class XCSwiftc {
    private let command: String
    private let inputArgs: SwiftcArgInput
    private let dependenciesWriterFactory: (URL, FileManager) -> DependenciesWriter
    private let touchFactory: (URL, FileManager) -> Touch

    public init(
        command: String,
        inputArgs: SwiftcArgInput,
        dependenciesWriter: @escaping (URL, FileManager) -> DependenciesWriter,
        touchFactory: @escaping (URL, FileManager) -> Touch
    ) {
        self.command = command
        self.inputArgs = inputArgs
        dependenciesWriterFactory = dependenciesWriter
        self.touchFactory = touchFactory
    }

    // swiftlint:disable:next function_body_length
    public func run() {
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: SwiftcContext
        do {
            let srcRoot: URL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            config = try XCRemoteCacheConfigReader(srcRootPath: srcRoot.path, fileReader: fileManager)
                .readConfiguration()
            context = try SwiftcContext(config: config, input: inputArgs)
        } catch {
            exit(1, "FATAL: Swiftc initialization failed with error: \(error)")
        }
        let swiftcCommand = config.swiftcCommand
        let markerURL = context.tempDir.appendingPathComponent(config.modeMarkerPath)
        let markerReader = FileMarkerReader(markerURL, fileManager: fileManager)
        let markerWriter = FileMarkerWriter(markerURL, fileAccessor: fileManager)

        let inputReader = SwiftcFilemapInputEditor(context.filemap, fileManager: fileManager)
        let fileListEditor = FileListEditor(context.fileList, fileManager: fileManager)
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
        let productsGenerator = DiskSwiftcProductsGenerator(
            modulePathOutput: context.modulePathOutput,
            objcHeaderOutput: context.objcHeaderOutput,
            diskCopier: HardLinkDiskCopier(fileManager: fileManager)
        )
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
            inputFileListReader: fileListEditor,
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
    }
}
