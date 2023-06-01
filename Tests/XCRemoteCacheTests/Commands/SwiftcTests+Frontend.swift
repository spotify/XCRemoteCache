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
class SwiftcTests_Frontend: FileXCTestCase {
    private let dummyURL = URL(fileURLWithPath: "")

    private var inputFileListReader: ListReader!
    private var markerReader: ListReader!
    private var allowedFilesListScanner: FileListScanner!
    private var artifactOrganizer: ArtifactOrganizer!
    private var swiftcInputReader: SwiftcInputReader!
    private var config: XCRemoteCacheConfig!
    private var input: SwiftFrontendArgInput!
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
        _ = workingDir.appendingPathComponent("Objects-normal")
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

        input = SwiftFrontendArgInput(
            compile: true,
            emitModule: false,
            objcHeaderOutput: nil,
            moduleName: "Module",
            target: "Target",
            primaryInputPaths: [],
            inputPaths: [],
            outputPaths: [],
            dependenciesPaths: [],
            diagnosticsPaths: [],
            sourceInfoPath: nil,
            docPath: nil,
            supplementaryOutputFileMap: nil
        )
        context = try SwiftcContext(config: config, input: input)
        markerWriter = MarkerWriterSpy()
        productsGenerator = SwiftcProductsGeneratorSpy(
            generatedDestination: SwiftcProductsGeneratorOutput(swiftmoduleDir: "", objcHeaderFile: "")
        )
        let dependenciesWriterSpy = DependenciesWriterSpy()
        self.dependenciesWriterSpy = dependenciesWriterSpy
        dependenciesWriterFactory = { [dependenciesWriterSpy] _, _ in dependenciesWriterSpy }
        touchFactory = { _, _ in TouchSpy() }
    } // swiftlint:disable:next file_length
}
