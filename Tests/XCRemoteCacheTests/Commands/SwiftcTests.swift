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

@testable import XCRemoteCache
import XCTest

// swiftlint:disable:next type_body_length
class SwiftcTests: FileXCTestCase {
    private let dummyURL = URL(fileURLWithPath: "")

    private var inputFileListReader: ListReader!
    private var markerReader: ListReader!
    private var allowedFilesListScanner: FileListScanner!
    private var artifactOrganizer: ArtifactOrganizer!
    private var swiftcInputReader: SwiftcInputReader!
    private var config: XCRemoteCacheConfig!
    private var input: SwiftcArgInput!
    private var context: SwiftcContext!
    private var markerWriter: MarkerWriterSpy!
    private var productsGenerator: SwiftcProductsGeneratorSpy!
    private var dependenciesWriterSpy: DependenciesWriterSpy!
    private var dependenciesWriterFactory: ((URL, FileManager) -> DependenciesWriter)!
    private var touchFactory: ((URL, FileManager) -> Touch)!
    private var workingDir: URL!
    private var remoteCommitLocation: URL!
    private let sampleRemoteCommit = "bdb321"


    override func setUpWithError() throws {
        try super.setUpWithError()
        workingDir = try prepareTempDir()
        let modulePathOutput = workingDir.appendingPathComponent("Objects-normal")
            .appendingPathComponent("archTest")
            .appendingPathComponent("Target.swiftmodule")
        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true, attributes: nil)

        inputFileListReader = ListReaderFake(files: [])
        markerReader = ListReaderFake(files: [])
        allowedFilesListScanner = FileListScannerFake(files: [])
        artifactOrganizer = ArtifactOrganizerFake()
        swiftcInputReader = SwiftcInputReaderStub()
        config = XCRemoteCacheConfig(remoteCommitFile: "arc.rc", sourceRoot: workingDir.path)
        // SwiftcContext reads remoteCommit from a file so writing to a temporary file `sampleRemoteCommit`
        remoteCommitLocation = URL(fileURLWithPath: config.sourceRoot).appendingPathComponent("arc.rc")
        try sampleRemoteCommit.write(to: remoteCommitLocation, atomically: true, encoding: .utf8)

        input = SwiftcArgInput(
            objcHeaderOutput: "Target-Swift.h",
            moduleName: "",
            modulePathOutput: modulePathOutput.path,
            filemap: "",
            target: "",
            fileList: ""
        )
        context = try SwiftcContext(config: config, input: input)
        markerWriter = MarkerWriterSpy()
        productsGenerator = SwiftcProductsGeneratorSpy()
        let dependenciesWriterSpy = DependenciesWriterSpy()
        self.dependenciesWriterSpy = dependenciesWriterSpy
        dependenciesWriterFactory = { [dependenciesWriterSpy] _, _ in dependenciesWriterSpy }
        touchFactory = { _, _ in TouchSpy() }
    }

    func testReturnsWithFallbackForDisabledRC() throws {
        let markerReader = ListReaderFake(files: nil)
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )

        let compilation = try swiftc.mockCompilation()

        XCTAssertEqual(compilation, .forceFallback)
    }

    func testReturnsFallbackForNotAllowedInputFile() throws {
        inputFileListReader = ListReaderFake(files: [URL(fileURLWithPath: "newFile.swift")])
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )

        let compilation = try swiftc.mockCompilation()

        XCTAssertEqual(compilation, .forceFallback)
    }

    func testModifiesPrebuildDiscoveryFileForNotAllowedInputFile() throws {
        inputFileListReader = ListReaderFake(files: [URL(fileURLWithPath: "newFile.swift")])
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )

        _ = try swiftc.mockCompilation()

        XCTAssertEqual(dependenciesWriterSpy.wroteSkipForSha, sampleRemoteCommit)
    }

    func testDoesntModifyPrebuildDiscoveryFileForNotAllowedInputFileIfGloballyDisabledCache() throws {
        try fileManager.write(toPath: remoteCommitLocation.path, contents: Data())
        context = try SwiftcContext(config: config, input: input)
        inputFileListReader = ListReaderFake(files: [URL(fileURLWithPath: "newFile.swift")])
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )

        _ = try swiftc.mockCompilation()

        XCTAssertNil(dependenciesWriterSpy.wroteSkipForSha)
    }

    func testProducerDoesntConsiderCommitShaFromArcRcFile() throws {
        try FileManager.default.removeItem(at: remoteCommitLocation)
        config.mode = .producer
        context = try SwiftcContext(config: config, input: input)

        inputFileListReader = ListReaderFake(files: [URL(fileURLWithPath: "newFile.swift")])
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )

        _ = try swiftc.mockCompilation()

        XCTAssertNil(dependenciesWriterSpy.wroteSkipForSha)
    }

    func testDisablesRCForNotAllowedInputFile() throws {
        inputFileListReader = ListReaderFake(files: [URL(fileURLWithPath: "newFile.swift")])
        let expectedPrebuildWriterURL = workingDir.appendingPathComponent(context.prebuildDependenciesPath)
        let writerSpy = DependenciesWriterSpy()
        var writerURL: URL?
        dependenciesWriterFactory = { url, _ in
            writerURL = url
            return writerSpy
        }
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )

        _ = try swiftc.mockCompilation()

        XCTAssertEqual(markerWriter.state, .disabled)
        XCTAssertEqual(writerURL, expectedPrebuildWriterURL)
        XCTAssertEqual(writerSpy.wroteSkipForSha, sampleRemoteCommit)
    }

    func testRCTouchesOutputFile() throws {
        let compilationURL = URL(fileURLWithPath: "old.swift")
        inputFileListReader = ListReaderFake(files: [compilationURL])
        markerReader = ListReaderFake(files: [compilationURL])
        allowedFilesListScanner = FileListScannerFake(files: [compilationURL])
        let objectURL = URL(fileURLWithPath: "object")
        let swiftFileCompilationInfo = SwiftFileCompilationInfo(
            file: compilationURL,
            dependencies: dummyURL.appendingPathExtension("dep"),
            object: objectURL,
            swiftDependencies: dummyURL
        )
        let compilationInfo = SwiftCompilationInfo(
            info: SwiftModuleCompilationInfo(
                dependencies: nil,
                swiftDependencies: dummyURL.appendingPathExtension("swiftdep")
            ),
            files: [swiftFileCompilationInfo]
        )
        swiftcInputReader = SwiftcInputReaderStub(info: compilationInfo)

        let touchSpy = TouchSpy()
        var touchURL: URL?
        touchFactory = { url, _ in
            touchURL = url
            return touchSpy
        }
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )

        _ = try swiftc.mockCompilation()

        XCTAssertEqual(touchURL, objectURL)
        XCTAssertTrue(touchSpy.touched)
    }

    func testCompilationUsesArchSpecificSwiftmoduleFiles() throws {
        let artifactRoot = URL(fileURLWithPath: "/cachedArtifact")
        let artifactObjCHeader = URL(fileURLWithPath: "/cachedArtifact/include/archTest/Target-Swift.h")
        let artifactSwiftmodule = URL(fileURLWithPath: "/cachedArtifact/swiftmodule/archTest/Target.swiftmodule")
        let artifactSwiftdoc = URL(fileURLWithPath: "/cachedArtifact/swiftmodule/archTest/Target.swiftdoc")
        let artifactSwiftSourceInfo = URL(
            fileURLWithPath: "/cachedArtifact/swiftmodule/archTest/Target.swiftsourceinfo"
        )
        let artifactSwiftInterfaceInfo = URL(
            fileURLWithPath: "/cachedArtifact/swiftmodule/archTest/Target.swiftinterface"
        )

        artifactOrganizer = ArtifactOrganizerFake(artifactRoot: artifactRoot)
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: []
        )

        _ = try swiftc.mockCompilation()

        let swiftModuleFiles = try productsGenerator.generated.first.unwrap()
        let swiftModuleURL = swiftModuleFiles.0[.swiftmodule]
        let swiftDocURL = swiftModuleFiles.0[.swiftdoc]
        let swiftSourceInfoURL = swiftModuleFiles.0[.swiftsourceinfo]
        let swiftInterfaceURL = swiftModuleFiles.0[.swiftinterface]
        let swiftHeaderURL = swiftModuleFiles.1

        XCTAssertEqual(swiftModuleURL, artifactSwiftmodule)
        XCTAssertEqual(swiftDocURL, artifactSwiftdoc)
        XCTAssertEqual(swiftSourceInfoURL, artifactSwiftSourceInfo)
        XCTAssertEqual(swiftHeaderURL, artifactObjCHeader)
        XCTAssertEqual(swiftInterfaceURL, artifactSwiftInterfaceInfo)
    }


    func testCallsPluginGeneration() throws {
        var pluginGenerated = false
        let plugin = ActionSwiftcProductGenerationPlugin {
            pluginGenerated = true
        }

        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: dependenciesWriterFactory,
            touchFactory: touchFactory,
            plugins: [plugin]
        )

        _ = try swiftc.mockCompilation()

        XCTAssertTrue(pluginGenerated)
    }

    func testGeneratesDFilesPerModuleAndIndividualFiles() throws {
        let outputFilesDir = workingDir.appendingPathComponent("outputFiles")
        try fileManager.spt_createEmptyDir(outputFilesDir)
        let moduleDFile = outputFilesDir.appendingPathComponent("master.d")
        let fileDFile = outputFilesDir.appendingPathComponent("file1.d")
        let input = SwiftCompilationInfo(
            info: SwiftModuleCompilationInfo(
                dependencies: moduleDFile,
                swiftDependencies: outputFilesDir.appendingPathComponent("master.swiftdeps")
            ),
            files: [
                SwiftFileCompilationInfo(
                    file: "/file1.swift",
                    dependencies: fileDFile,
                    object: outputFilesDir.appendingPathComponent("file1.o"),
                    swiftDependencies: nil
                ),
            ]
        )
        swiftcInputReader = SwiftcInputReaderStub(info: input)
        // files reported by a marker should be placed in the dependencies .d files
        markerReader = ListReaderFake(files: ["/file1.swift"])
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: FileDependenciesWriter.init,
            touchFactory: touchFactory,
            plugins: []
        )

        _ = try swiftc.mockCompilation()

        let moduleDReader = FileDependenciesReader(moduleDFile, accessor: .default)
        let fileDReader = FileDependenciesReader(fileDFile, accessor: .default)
        XCTAssertEqual(
            try moduleDReader.readFilesAndDependencies(),
            ["dependencies": ["/file1.swift"]]
        )
        XCTAssertEqual(
            try fileDReader.readFilesAndDependencies(),
            ["dependencies": ["/file1.swift"]]
        )
    }

    func testSkipsGeneratingDFilesWhenNotProvidedInCompilationInfo() throws {
        let outputFilesDir = workingDir.appendingPathComponent("outputFiles")
        try fileManager.spt_createEmptyDir(outputFilesDir)
        let input = SwiftCompilationInfo(
            info: SwiftModuleCompilationInfo(
                dependencies: nil,
                swiftDependencies: outputFilesDir.appendingPathComponent("master.swiftdeps")
            ),
            files: [
                SwiftFileCompilationInfo(
                    file: "/file1.swift",
                    dependencies: nil,
                    object: outputFilesDir.appendingPathComponent("file1.o"),
                    swiftDependencies: nil
                ),
            ]
        )
        swiftcInputReader = SwiftcInputReaderStub(info: input)
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: FileDependenciesWriter.init,
            touchFactory: touchFactory,
            plugins: []
        )

        XCTAssertNoThrow(try swiftc.mockCompilation())
    }

    func testSkipsGeneratingObjectFileWhenNotProvidedInCompilationInfo() throws {
        let outputFilesDir = workingDir.appendingPathComponent("outputFiles")
        try fileManager.spt_createEmptyDir(outputFilesDir)
        let input = SwiftCompilationInfo(
            info: SwiftModuleCompilationInfo(
                dependencies: nil,
                swiftDependencies: outputFilesDir.appendingPathComponent("master.swiftdeps")
            ),
            files: [
                SwiftFileCompilationInfo(
                    file: "/file1.swift",
                    dependencies: nil,
                    object: nil,
                    swiftDependencies: nil
                ),
            ]
        )
        swiftcInputReader = SwiftcInputReaderStub(info: input)
        let swiftc = Swiftc(
            inputFileListReader: inputFileListReader,
            markerReader: markerReader,
            allowedFilesListScanner: allowedFilesListScanner,
            artifactOrganizer: artifactOrganizer,
            inputReader: swiftcInputReader,
            context: context,
            markerWriter: markerWriter,
            productsGenerator: productsGenerator,
            fileManager: FileManager.default,
            dependenciesWriterFactory: FileDependenciesWriter.init,
            touchFactory: touchFactory,
            plugins: []
        )

        XCTAssertNoThrow(try swiftc.mockCompilation())
    } // swiftlint:disable:next file_length
}
