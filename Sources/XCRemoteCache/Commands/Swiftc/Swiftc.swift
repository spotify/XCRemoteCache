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

enum SwiftCResult {
    /// Swiftc mock cannot be used and fallback to the compilation is required
    case forceFallback
    /// All compilation steps were mocked correctly
    case success
}

/// Swiftc mocking compilation
protocol SwiftcProtocol {
    /// Tries to performs mocked compilation (moving all cached files to the expected location)
    /// If cached compilation products are not valid or incompatible, fallbacks to build-from-source
    /// - Returns: `.forceFallback` if the cached compilation products are incompatible and fallback
    ///  to a standard 'swiftc' is required, `.success` otherwise
    /// - Throws: An error if there was an unrecoverable, serious error (e.g. IO error)
    func mockCompilation() throws -> SwiftCResult
}

/// Swiftc wrapper that mocks compilation with noop and moves all expected products from cache location
class Swiftc: SwiftcProtocol {
    /// Reader of all input files of the compilation
    private let inputFileListReader: ListReader
    /// Reader of the marker file lists - list of dependencies to set for swiftc compilation
    private let markerReader: ListReader
    /// Checks if the input file exists in the file list
    private let allowedFilesListScanner: FileListScanner
    /// Manager of the downloaded artifact package
    private let artifactOrganizer: ArtifactOrganizer
    /// Reads all input and output files for the compilation from an input filemap
    private let inputFilesReader: SwiftcInputReader
    /// Write manager of the marker file
    private let markerWriter: MarkerWriter
    /// Generates products at the desired destination
    private let productsGenerator: SwiftcProductsGenerator
    private let context: SwiftcContext
    private let fileManager: FileManager
    private let dependenciesWriterFactory: (URL, FileManager) -> DependenciesWriter
    private let touchFactory: (URL, FileManager) -> Touch
    private let plugins: [SwiftcProductGenerationPlugin]

    init(
        inputFileListReader: ListReader,
        markerReader: ListReader,
        allowedFilesListScanner: FileListScanner,
        artifactOrganizer: ArtifactOrganizer,
        inputReader: SwiftcInputReader,
        context: SwiftcContext,
        markerWriter: MarkerWriter,
        productsGenerator: SwiftcProductsGenerator,
        fileManager: FileManager,
        dependenciesWriterFactory: @escaping (URL, FileManager) -> DependenciesWriter,
        touchFactory: @escaping (URL, FileManager) -> Touch,
        plugins: [SwiftcProductGenerationPlugin]
    ) {
        self.inputFileListReader = inputFileListReader
        self.markerReader = markerReader
        self.allowedFilesListScanner = allowedFilesListScanner
        self.artifactOrganizer = artifactOrganizer
        inputFilesReader = inputReader
        self.context = context
        self.markerWriter = markerWriter
        self.productsGenerator = productsGenerator
        self.fileManager = fileManager
        self.dependenciesWriterFactory = dependenciesWriterFactory
        self.touchFactory = touchFactory
        self.plugins = plugins
    }

    // TODO: consider refactoring to a separate entity
    private func assetsGeneratedSources(inputFiles: [URL]) -> [URL] {
        return inputFiles.filter { url in
            url.lastPathComponent == "\(DependencyProcessorImpl.GENERATED_ASSETS_FILENAME).swift"
        }
    }

    // swiftlint:disable:next function_body_length
    func mockCompilation() throws -> SwiftCResult {
        let rcModeEnabled = markerReader.canRead()
        guard rcModeEnabled else {
            infoLog("Swiftc marker doesn't exist")
            return .forceFallback
        }

        let inputFilesInputs = try inputFileListReader.listFilesURLs()
        let markerAllowedFiles = try markerReader.listFilesURLs()
        let generatedAssetsFiles = assetsGeneratedSources(inputFiles: inputFilesInputs)
        let cachedDependenciesWriterFactory = CachedFileDependenciesWriterFactory(
            dependencies: markerAllowedFiles + generatedAssetsFiles,
            fileManager: fileManager,
            writerFactory: dependenciesWriterFactory
        )
        // Verify all input files to be present in a marker fileList
        let disallowedInputs = try inputFilesInputs.filter { try !allowedFilesListScanner.contains($0) && !generatedAssetsFiles.contains($0) }

        if !disallowedInputs.isEmpty {
            // New file (disallowedFile) added without modifying the rest of the feature. Fallback to swiftc and
            // ensure that compilation from source will be forced up until next merge/rebase with "primary" branch
            infoLog("Swiftc new input file \(disallowedInputs)")
            // Deleting marker to indicate that the remote cached artifact cannot be used
            try markerWriter.disable()

            // Save custom prebuild discovery content to make sure that the following prebuild
            // phase will not try to reuse cached artifact (if present)
            // In other words: let prebuild know that it should not try to reenable cache
            // until the next merge with primary
            switch context.mode {
            case .consumer(commit: .available(let remoteCommit)):
                let prebuildDiscoveryURL = context.tempDir.appendingPathComponent(context.prebuildDependenciesPath)
                let prebuildDiscoverWriter = dependenciesWriterFactory(prebuildDiscoveryURL, fileManager)
                try prebuildDiscoverWriter.write(skipForSha: remoteCommit)
            case .consumer, .producer, .producerFast:
                // Never skip prebuild phase and fallback to the swiftc compilation for:
                // 1) Not enabled remote cache, 2) producer(s)
                break
            }
            return .forceFallback
        }

        let artifactLocation = artifactOrganizer.getActiveArtifactLocation()

        // Read swiftmodule location from XCRemoteCache
        // arbitrary format swiftmodule/${arch}/${moduleName}.swift{module|doc|sourceinfo}
        let moduleName = context.moduleName
        let allCompilations = try inputFilesReader.read()
        let artifactSwiftmoduleDir = artifactLocation
            .appendingPathComponent("swiftmodule")
            .appendingPathComponent(context.arch)
        let artifactSwiftmoduleBase = artifactSwiftmoduleDir.appendingPathComponent(moduleName)
        let artifactSwiftmoduleFiles = Dictionary(
            uniqueKeysWithValues: SwiftmoduleFileExtension.SwiftmoduleExtensions
                .map { ext, _ in
                    (ext, artifactSwiftmoduleBase.appendingPathExtension(ext.rawValue))
                }
        )

        // emit module (if requested)
        if let emitModule = context.steps.emitModule {
            // Build -Swift.h location from XCRemoteCache arbitrary format include/${arch}/${target}-Swift.h
            let artifactSwiftModuleObjCDir = artifactLocation
                .appendingPathComponent("include")
                .appendingPathComponent(context.arch)
                .appendingPathComponent(context.moduleName)
            // Move cached xxxx-Swift.h to the location passed in arglist
            // Alternatively, artifactSwiftModuleObjCFile could be built as a first .h
            // file in artifactSwiftModuleObjCDir
            let artifactSwiftModuleObjCFile = artifactSwiftModuleObjCDir
                .appendingPathComponent(emitModule.objcHeaderOutput.lastPathComponent)

            _ = try productsGenerator.generateFrom(
                artifactSwiftModuleFiles: artifactSwiftmoduleFiles,
                artifactSwiftModuleObjCFile: artifactSwiftModuleObjCFile
            )
        }

        try plugins.forEach {
            try $0.generate(for: allCompilations)
        }

        // Save individual .d and touch .o for each .swift file
        for compilation in allCompilations.files {
            if let object = compilation.object {
                // Touching .o is required to invalidate already existing .a or linked library
                let touch = touchFactory(object, fileManager)
                try touch.touch()
            }
            if let individualDeps = compilation.dependencies {
                // swiftc product should be invalidated if any of dependencies file has changed
                try cachedDependenciesWriterFactory.generate(output: individualDeps)
            }
        }
        // Save .d for the entire module (might not be required in the `swift-frontend -c` mode)
        if let swiftDependencies = allCompilations.info.swiftDependencies {
            try cachedDependenciesWriterFactory.generate(output: swiftDependencies)
        }
        // Generate .d file with all deps in the "-master.d" (e.g. for WMO)
        if let wmoDeps = allCompilations.info.dependencies {
            try cachedDependenciesWriterFactory.generate(output: wmoDeps)
        }
        infoLog("Swiftc noop for \(context.target)")
        return .success
    }
}
