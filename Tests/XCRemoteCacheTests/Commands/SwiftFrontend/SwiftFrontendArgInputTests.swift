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

@testable import XCRemoteCache
import XCTest

class SwiftFrontendArgInputTests: FileXCTestCase {
    private var compile: Bool = true
    private var emitModule: Bool = false
    private var objcHeaderOutput: String?
    private var moduleName: String?
    private var target: String?
    private var primaryInputPaths: [String] = []
    private var inputPaths: [String] = []
    private var outputPaths: [String] = []
    private var dependenciesPaths: [String] = []
    private var diagnosticsPaths: [String] = []
    private var sourceInfoPath: String?
    private var docPath: String?
    private var supplementaryOutputFileMap: String?

    private var config: XCRemoteCacheConfig!
    private var input: SwiftFrontendArgInput!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let workingDir = try prepareTempDir()
        let remoteCommitFile = workingDir.appendingPathComponent("arc.rc")
        config = XCRemoteCacheConfig(remoteCommitFile: remoteCommitFile.path, sourceRoot: workingDir.path)
        config.recommendedCacheAddress = "http://test.com"

        buildInput()
    }

    private func buildInput() {
        input = SwiftFrontendArgInput(
            compile: compile,
            emitModule: emitModule,
            objcHeaderOutput: objcHeaderOutput,
            moduleName: moduleName,
            target: target,
            primaryInputPaths: primaryInputPaths,
            inputPaths: inputPaths,
            outputPaths: outputPaths,
            dependenciesPaths: dependenciesPaths,
            diagnosticsPaths: diagnosticsPaths,
            sourceInfoPath: sourceInfoPath,
            docPath: docPath,
            supplementaryOutputFileMap: supplementaryOutputFileMap)
    }

    private func assertGenerationError(_ expectedError: SwiftFrontendArgInputError) {
        XCTAssertThrowsError(try input.generateSwiftcContext(config: config)) { error in
            guard let e = error as? SwiftFrontendArgInputError else {
                XCTFail("Received invalid error \(error). Expected: \(expectedError)")
                return
            }
            XCTAssertEqual(e, expectedError)
        }
    }

    func testFailsForNoStep() throws {
        compile = false
        emitModule = false
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.bothCompilationAndEmitAction)
    }

    func testFailsIfNoCompilationFiles() throws {
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.noCompilationInputs)
    }

    func testFailsIfNoTarget() throws {
        inputPaths = ["/file1"]
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.emitMissingTarget)
    }

    func testFailsIfNoModuleName() throws {
        inputPaths = ["/file1"]
        target = "Target"
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.emiMissingModuleName)
    }

    func testFailsIfNoCompileHasNoPrimaryInputs() throws {
        inputPaths = ["/file1"]
        target = "Target"
        moduleName = "Module"
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.noPrimaryFileCompilationInputs)
    }

    func testFailsIfDependenciesAreMissing() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1","/file2"]
        dependenciesPaths = ["/file1.d"]
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.dependenciesOuputCountDoesntMatch(expected: 2, parsed: 1))
    }

    func testDoesntFailForMissingDependenciesIfNoDependencies() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1","/file2"]
        dependenciesPaths = []
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.outputsOuputCountDoesntMatch(expected: 2, parsed: 0))
    }

    func testFailsIfDiagnosticsAreMissing() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1","/file2"]
        diagnosticsPaths = ["/file1.d"]
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.diagnosticsOuputCountDoesntMatch(expected: 2, parsed: 1))
    }

    func testDoesntFailForMissingDdiagnosticsIfNoDiagnostics() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1","/file2"]
        diagnosticsPaths = []
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.outputsOuputCountDoesntMatch(expected: 2, parsed: 0))
    }

    func testFailsIfOutputsAreMissing() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1","/file2"]
        outputPaths = ["/file1.o"]
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.outputsOuputCountDoesntMatch(expected: 2, parsed: 1))
    }

    func testSetsCompilationSubsetForCompilation() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1"]
        outputPaths = ["/file1.o"]
        buildInput()

        let context = try input.generateSwiftcContext(config: config)

        XCTAssertEqual(context.steps, .init(
            compileFilesScope: .subset(["/file1"]),
            emitModule: .none
        ))
    }

    func testBuildCompilationFilesInputs() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1"]
        outputPaths = ["/file1.o"]
        dependenciesPaths = ["/file1.d"]
        buildInput()

        let context = try input.generateSwiftcContext(config: config)

        XCTAssertEqual(context.inputs, .map([
            "/file1": SwiftFileCompilationInfo(
                file: "/file1",
                dependencies: "/file1.d",
                object: "/file1.o",
                swiftDependencies: nil
            )
        ])
        )
    }

    func testRecognizesArchFromOuputFirstPaths() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1"]
        outputPaths = ["/TARGET_TEMP_DIR/Object-normal/arm64/file1.o"]
        dependenciesPaths = ["/file1.d"]
        buildInput()

        let context = try input.generateSwiftcContext(config: config)

        XCTAssertEqual(context.arch, "arm64")
    }

    func testPassesExtraParams() throws {
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        primaryInputPaths = ["/file1"]
        outputPaths = ["/file1.o"]
        dependenciesPaths = ["/file1.d"]
        buildInput()

        let context = try input.generateSwiftcContext(config: config)

        XCTAssertEqual(context.moduleName, "Module")
        XCTAssertEqual(context.target, "Target")
        XCTAssertEqual(context.compilationFiles, .list(inputPaths))
        XCTAssertEqual(context.mode, .consumer(commit: .unavailable))
    }

    func testEmitModuleFailsForMissingOutput() throws {
        emitModule = true
        compile = false
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        outputPaths = []
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.emitModulOuputCountIsNot1(parsed: 0))
    }

    func testEmitModuleFailsForMissingObjcHeader() throws {
        emitModule = true
        compile = false
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        outputPaths = ["/Module.swiftmodule"]
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.emitModuleMissingObjcHeaderPath)
    }

    func testEmitModuleFailsForExcessiveDiagnostics() throws {
        emitModule = true
        compile = false
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        outputPaths = ["/Module.swiftmodule"]
        objcHeaderOutput = "/file-Swift.h"
        diagnosticsPaths = ["/file.diag", "/file2.diag"]
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.emitModuleDiagnosticsOuputCountIsHigherThan1(parsed: 2))
    }

    func testEmitModuleFailsForExcessiveDependencies() throws {
        emitModule = true
        compile = false
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        outputPaths = ["/Module.swiftmodule"]
        objcHeaderOutput = "/file-Swift.h"
        dependenciesPaths = ["/file.d", "/file2.d"]
        buildInput()

        assertGenerationError(SwiftFrontendArgInputError.emitModuleDependenciesOuputCountIsHigherThan1(parsed: 2))
    }

    func testEmitModuleSetsStep() throws {
        emitModule = true
        compile = false
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        outputPaths = ["/Module.swiftmodule"]
        objcHeaderOutput = "/file-Swift.h"
        diagnosticsPaths = ["/file.dia"]
        dependenciesPaths = ["/file.d"]
        buildInput()

        let context = try input.generateSwiftcContext(config: config)

        XCTAssertEqual(context.steps, .init(
            compileFilesScope: .none,
            emitModule: .init(
                objcHeaderOutput: "/file-Swift.h",
                modulePathOutput: "/Module.swiftmodule",
                dependencies: "/file.d"))
        )
    }

    func testEmitModuleSetsAllIntpus() throws {
        emitModule = true
        compile = false
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        outputPaths = ["/Module.swiftmodule"]
        objcHeaderOutput = "/file-Swift.h"
        buildInput()

        let context = try input.generateSwiftcContext(config: config)

        XCTAssertEqual(context.compilationFiles, .list(inputPaths))
    }

    func testEmitModuleRecognizesArchFromObjCHeader() throws {
        emitModule = true
        compile = false
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        outputPaths = ["file.swiftmodule"]
        objcHeaderOutput = "/TARGET_TEMP_DIR/Object-normal/arm64/file-Swift.h"
        buildInput()

        let context = try input.generateSwiftcContext(config: config)

        XCTAssertEqual(context.arch, "arm64")
    }

    func testEmitModulePassesExtraParams() throws {
        emitModule = true
        compile = false
        inputPaths = ["/file1","/file2","/file3"]
        target = "Target"
        moduleName = "Module"
        outputPaths = ["/Module.swiftmodule"]
        objcHeaderOutput = "/file-Swift.h"
        buildInput()

        let context = try input.generateSwiftcContext(config: config)

        XCTAssertEqual(context.moduleName, "Module")
        XCTAssertEqual(context.target, "Target")
        XCTAssertEqual(context.compilationFiles, .list(inputPaths))
        XCTAssertEqual(context.mode, .consumer(commit: .unavailable))
    }
}
