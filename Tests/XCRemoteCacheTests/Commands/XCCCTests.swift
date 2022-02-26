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

/// Integration test that verifies compiled `xccc` command wrapper
// swiftlint:disable:next type_body_length
class TemplateBasedCCWrapperBuilderTests: FileXCTestCase {
    private static let command = "clang"
    private static let marker = "enable.rc"
    private static let history = "history.compile"
    private static let prebuild = "prebuild.d"
    private static let commitSha = "321"
    private static let timeout = 10.0

    static let xccc: URL = {
        let fileManager = FileManager.default
        let builder = TemplateBasedCCWrapperBuilder(
            clangCommand: command,
            markerPath: marker,
            cachedTargetMockFilename: "stub",
            prebuildDFilename: prebuild,
            compilationHistoryFilename: history,
            shellOut: shellGetStdout,
            fileManager: fileManager
        )

        let appDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("compiled")
        let app = appDir.appendingPathComponent("xccc")
        try? fileManager.removeItem(at: appDir)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        try! builder.compile(to: app, commitSha: commitSha)
        return app
    }()

    private var directory: URL!
    private var dependencyFile: URL!
    private var outputFile: URL!
    private var inputFile: URL!
    private var markerFile: URL!
    private var historyFile: URL!
    private var prebuildFile: URL!
    private var arguments: [String]!

    override func setUpWithError() throws {
        try super.setUpWithError()

        directory = try prepareTempDir()
        // `xccc` recognizes TARGET_TEMP_FIR from -MF file with "../.."
        let dependencyFileDir = directory.appendingPathComponent("a/b")
        try fileManager.createDirectory(at: dependencyFileDir, withIntermediateDirectories: true, attributes: nil)
        dependencyFile = dependencyFileDir.appendingPathComponent("dep.d")

        outputFile = directory.appendingPathComponent("output.o")
        inputFile = directory.appendingPathComponent("input.m")
        markerFile = directory.appendingPathComponent(Self.marker)
        historyFile = directory.appendingPathComponent(Self.history)
        prebuildFile = directory.appendingPathComponent(Self.prebuild)
        arguments = ["-MF", dependencyFile.path, "-o", outputFile.path, inputFile.path]
    }

    func testAddsToCompileHistory() throws {
        fileManager.createFile(atPath: markerFile.path, contents: inputFile.path.data(using: .utf8), attributes: nil)
        fileManager.createFile(atPath: historyFile.path, contents: nil, attributes: nil)
        let expectedContent = try expectedCompileHistoryContent(arguments: arguments)

        try shellExec(Self.xccc.path, args: arguments, inDir: directory.path)

        let content = try fileManager.contents(atPath: historyFile.path).unwrap()
        XCTAssertEqual(content, expectedContent)
    }

    func testEscapesInputInCompileHistory() throws {
        arguments = ["-MF", dependencyFile.path, "-o", outputFile.path, inputFile.path, "-other", "\"\""]
        fileManager.createFile(atPath: markerFile.path, contents: inputFile.path.data(using: .utf8), attributes: nil)
        fileManager.createFile(atPath: historyFile.path, contents: nil, attributes: nil)
        let expectedContent = try expectedCompileHistoryContent(arguments: arguments)

        try shellExec(Self.xccc.path, args: arguments, inDir: directory.path)

        let content = try fileManager.contents(atPath: historyFile.path).unwrap()
        XCTAssertEqual(content, expectedContent)
    }

    func testFailsOnClangError() throws {
        // `inputFile` doesn't exists so `clang` should fail
        XCTAssertThrowsError(try shellExec(Self.xccc.path, args: arguments, inDir: directory.path))
    }

    /// Verifies that the xccc called when compile.history file is locked, waits with appending until it unlocks:
    /// 1. Acquire a lock
    /// 2. Start `xccc`
    /// 3. Verify that `xccc` is waiting
    /// 4. Release the lock
    /// 5. Wait until the `xccc` finishes
    /// 6. Expect history.compile is appended with xccc command
    func testAddsExclusivlyToCompileHistory() throws {
        fileManager.createFile(atPath: markerFile.path, contents: inputFile.path.data(using: .utf8), attributes: nil)
        fileManager.createFile(atPath: historyFile.path, contents: nil, attributes: nil)
        let historyFileAccess = ExclusiveFile(historyFile, mode: .append)
        let previousContent = try "Initial\n".data(using: .utf8).unwrap()
        let expectedContent = try previousContent + expectedCompileHistoryContent(arguments: arguments)
        let started = expectation(description: "Started xccc")
        let finished = expectation(description: "Finished xccc")

        try historyFileAccess.exclusiveAccess { file in
            var commandFinished = false
            DispatchQueue.global(qos: .default).async {
                let process = try? startExec(Self.xccc.path, args: self.arguments, inDir: self.directory.path)
                started.fulfill()
                _ = process.flatMap(waitFor)
                commandFinished = true
                finished.fulfill()
            }
            wait(for: [started], timeout: Self.timeout)
            file.write(previousContent)
            XCTAssertFalse(commandFinished)
        }

        waitForExpectations(timeout: Self.timeout)
        let content = try fileManager.contents(atPath: historyFile.path).unwrap()
        XCTAssertEqual(content, expectedContent)
    }

    /// Verifies that two `xccc` calls
    /// 1. Acquire a lock
    /// 2. Start `xccc`
    /// 3. Start another `xccc`
    /// 4. Release the lock
    /// 5. Wait until `xccc`s finish
    /// 6. Expect `history.compile` has 2 invocations
    func testTwoCallsAppendExclusivlyToCompileHistory() throws {
        fileManager.createFile(atPath: markerFile.path, contents: inputFile.path.data(using: .utf8), attributes: nil)
        fileManager.createFile(atPath: historyFile.path, contents: nil, attributes: nil)
        let historyFileAccess = ExclusiveFile(historyFile, mode: .append)
        let singleCommandArgs = try expectedCompileHistoryContent(arguments: arguments)
        let expectedContent = singleCommandArgs + singleCommandArgs
        let started = expectation(description: "Started xccc")
        let finished = expectation(description: "Finished xccc")
        started.expectedFulfillmentCount = 2
        finished.expectedFulfillmentCount = 2

        try historyFileAccess.exclusiveAccess { _ in
            DispatchQueue.global(qos: .default).async {
                let process = try? startExec(Self.xccc.path, args: self.arguments, inDir: self.directory.path)
                started.fulfill()
                _ = process.flatMap(waitFor)
                finished.fulfill()
            }
            DispatchQueue.global(qos: .default).async {
                let process = try? startExec(Self.xccc.path, args: self.arguments, inDir: self.directory.path)
                started.fulfill()
                _ = process.flatMap(waitFor)
                finished.fulfill()
            }
            wait(for: [started], timeout: Self.timeout)
        }

        waitForExpectations(timeout: Self.timeout)
        let content = try fileManager.contents(atPath: historyFile.path).unwrap()
        XCTAssertEqual(content, expectedContent)
    }

    /// Verifies that removed history.compile (when some other process hold a lock) fallbacks to the local compilation
    func testFallbacksIfCompileHistoryIsRemoved() throws {
        fileManager.createFile(
            atPath: markerFile.path,
            contents: "\(inputFile.path)".data(using: .utf8),
            attributes: nil
        )
        fileManager.createFile(atPath: historyFile.path, contents: nil, attributes: nil)
        createValidCFile(inputFile)
        let historyFileAccess = ExclusiveFile(historyFile, mode: .append)
        let started = expectation(description: "Started xccc")
        let finished = expectation(description: "Finished xccc")

        try historyFileAccess.exclusiveAccess { _ in
            DispatchQueue.global(qos: .default).async {
                let process = try? startExec(Self.xccc.path, args: self.arguments, inDir: self.directory.path)
                started.fulfill()
                _ = process.flatMap(waitFor)
                finished.fulfill()
            }
            wait(for: [started], timeout: Self.timeout)
            try fileManager.removeItem(atPath: historyFile.path)
        }

        waitForExpectations(timeout: Self.timeout)
        XCTAssertTrue(fileManager.fileExists(atPath: outputFile.path))
        // Make sure history.compile is not regenerated
        XCTAssertFalse(fileManager.fileExists(atPath: historyFile.path))
    }

    func testNewFileFallbacksToClang() throws {
        // Marker is empty to mimic the new file scenario
        fileManager.createFile(atPath: markerFile.path, contents: nil, attributes: nil)
        fileManager.createFile(atPath: historyFile.path, contents: nil, attributes: nil)
        createValidCFile(inputFile)

        try shellExec(Self.xccc.path, args: arguments, inDir: directory.path)

        XCTAssertTrue(fileManager.fileExists(atPath: outputFile.path))
        XCTAssertFalse(fileManager.fileExists(atPath: historyFile.path))
        XCTAssertFalse(fileManager.fileExists(atPath: markerFile.path))
        let prebuildDData = try String(data: fileManager.contents(atPath: prebuildFile.path).unwrap(), encoding: .utf8)
        XCTAssertEqual(prebuildDData, "skipForSha: 321\n")
    }

    func testNewFileCallsCompileHistory() throws {
        fileManager.createFile(atPath: markerFile.path, contents: nil, attributes: nil)
        let oldInput1 = directory.appendingPathComponent("inputOld1.m")
        let oldOutput1 = directory.appendingPathComponent("outputOld1.o")
        let oldInput2 = directory.appendingPathComponent("inputOld2.m")
        let oldOutput2 = directory.appendingPathComponent("outputOld2.o")
        createValidCFile(oldInput1)
        createValidCFile(oldInput2)
        createValidCFile(inputFile)
        let oldClangCompilationArguments1 = ["-MF", dependencyFile.path, "-o", oldOutput1.path, oldInput1.path]
        let oldClangCompilationArguments2 = ["-MF", dependencyFile.path, "-o", oldOutput2.path, oldInput2.path]
        let compileHistory1 = try expectedCompileHistoryContent(arguments: oldClangCompilationArguments1)
        let compileHistory2 = try expectedCompileHistoryContent(arguments: oldClangCompilationArguments2)
        fileManager.createFile(atPath: historyFile.path, contents: compileHistory1 + compileHistory2, attributes: nil)

        try shellExec(Self.xccc.path, args: arguments, inDir: directory.path)

        XCTAssertTrue(fileManager.fileExists(atPath: oldOutput1.path))
        XCTAssertTrue(fileManager.fileExists(atPath: oldOutput2.path))
    }

    func testCompilesFromCompileHistoryWhenNewFileIdentified() throws {
        fileManager.createFile(atPath: markerFile.path, contents: nil, attributes: nil)
        let oldInput = directory.appendingPathComponent("inputOld.m")
        let oldOutput = directory.appendingPathComponent("outputOld.o")
        createValidCFile(oldInput)
        createValidCFile(inputFile)
        let oldClangCompilationArguments = ["-MF", dependencyFile.path, "-o", oldOutput.path, oldInput.path]
        let compileHistory = try expectedCompileHistoryContent(arguments: oldClangCompilationArguments)
        fileManager.createFile(atPath: historyFile.path, contents: compileHistory, attributes: nil)

        try shellExec(Self.xccc.path, args: arguments, inDir: directory.path)

        XCTAssertTrue(fileManager.fileExists(atPath: oldOutput.path))
        XCTAssertTrue(fileManager.fileExists(atPath: outputFile.path))
        XCTAssertFalse(fileManager.fileExists(atPath: historyFile.path))
    }

    func testCompileHistoryErrorStopsCompilingNewFile() throws {
        fileManager.createFile(atPath: markerFile.path, contents: nil, attributes: nil)
        let oldInput = directory.appendingPathComponent("inputOld.m")
        let oldOutput = directory.appendingPathComponent("outputOld.o")
        createInvalidCFile(oldInput)
        createValidCFile(inputFile)
        let oldClangCompilationArguments = ["-MF", dependencyFile.path, "-o", oldOutput.path, oldInput.path]
        let compileHistory = try expectedCompileHistoryContent(arguments: oldClangCompilationArguments)
        fileManager.createFile(atPath: historyFile.path, contents: compileHistory, attributes: nil)

        // First compiles old file from compileHistory that fails due to missing Macro in the compile command
        let process = try? startExec(Self.xccc.path, args: arguments, inDir: directory.path)
        let exitStatus = try process.flatMap(waitFor).unwrap()

        XCTAssertFalse(fileManager.fileExists(atPath: oldOutput.path))
        XCTAssertFalse(fileManager.fileExists(atPath: outputFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: historyFile.path))
        let prebuildDData = try String(data: fileManager.contents(atPath: prebuildFile.path).unwrap(), encoding: .utf8)
        XCTAssertEqual(prebuildDData, "skipForSha: 321\n")
        XCTAssertGreaterThan(exitStatus, 0)
    }

    func testInvalidNewFileStopsCompilation() throws {
        fileManager.createFile(atPath: markerFile.path, contents: nil, attributes: nil)
        let oldInput = directory.appendingPathComponent("inputOld.m")
        let oldOutput = directory.appendingPathComponent("outputOld.o")
        createValidCFile(oldInput)
        createInvalidCFile(inputFile)
        let oldClangCompilationArguments = ["-MF", dependencyFile.path, "-o", oldOutput.path, oldInput.path]
        let compileHistory = try expectedCompileHistoryContent(arguments: oldClangCompilationArguments)
        fileManager.createFile(atPath: historyFile.path, contents: compileHistory, attributes: nil)

        // First compiles old file from compileHistory (success) followed by input.m (failure)
        let process = try? startExec(Self.xccc.path, args: arguments, inDir: directory.path)
        let exitStatus = try process.flatMap(waitFor).unwrap()

        XCTAssertTrue(fileManager.fileExists(atPath: oldOutput.path))
        XCTAssertFalse(fileManager.fileExists(atPath: outputFile.path))
        XCTAssertGreaterThan(exitStatus, 0)
    }

    func testReusingPreviousComplexClangCommandFromHistory() throws {
        fileManager.createFile(atPath: markerFile.path, contents: inputFile.path.data(using: .utf8), attributes: nil)
        fileManager.createFile(atPath: historyFile.path, contents: nil, attributes: nil)
        let newFile = directory.appendingPathComponent("newFile.m")
        let newFileOutput = directory.appendingPathComponent("newFile.o")
        createInvalidCFile(inputFile)
        createValidCFile(newFile)
        let fileClangArgs = ["-MF", dependencyFile.path, "-o", outputFile.path, "-DCUSTOM_STR=\"\"", inputFile.path]
        let newFileClangArgs = ["-MF", dependencyFile.path, "-o", newFileOutput.path, newFile.path]

        // call xccc that should mock compilation (noop) of inputFile.m
        try shellExec(Self.xccc.path, args: fileClangArgs, inDir: directory.path)
        // Empty file indicages skipped inputFile.m compilation
        var outputData = try fileManager.contents(atPath: outputFile.path).unwrap()
        XCTAssertEqual(outputData, Data())
        let historyData = try fileManager.contents(atPath: historyFile.path).unwrap()
        XCTAssertEqual(historyData, try expectedCompileHistoryContent(arguments: fileClangArgs))

        // compiles old file from compileHistory (success) followed by input.m compilation (success)
        try shellExec(Self.xccc.path, args: newFileClangArgs, inDir: directory.path)

        XCTAssertTrue(fileManager.fileExists(atPath: newFileOutput.path))
        // Non-empty .o indicates local compilation of inputFile.m and "newFile.m"
        outputData = try fileManager.contents(atPath: outputFile.path).unwrap()
        XCTAssertNotEqual(outputData, Data())
        let newFileOutputData = try fileManager.contents(atPath: newFileOutput.path).unwrap()
        XCTAssertNotEqual(newFileOutputData, Data())
    }

    func testPCHCompilationFallbacks() throws {
        // Marker is empty to mimic the new file scenario
        let pchFile = directory.appendingPathComponent("input.pch")
        createValidPCCFile(pchFile)
        arguments = ["-x", "objective-c-header", "-MF", dependencyFile.path, "-o", outputFile.path, pchFile.path]

        try shellExec(Self.xccc.path, args: arguments, inDir: directory.path)

        XCTAssertTrue(fileManager.fileExists(atPath: outputFile.path))
    }

    /// Creates a simple C code in the location
    private func createValidCFile(_ location: URL) {
        fileManager.createFile(atPath: location.path, contents: "int main(){}".data(using: .utf8), attributes: nil)
    }

    /// Creates a simple PCH code in the location
    private func createValidPCCFile(_ location: URL) {
        fileManager.createFile(atPath: location.path, contents: "#import <Availability.h>".data(using: .utf8), attributes: nil)
    }

    /// Creates a C code that requires extra CUSTOM_STR clang macro to compile
    private func createInvalidCFile(_ location: URL) {
        fileManager.createFile(
            atPath: location.path,
            contents: "int main(){char *str = CUSTOM_STR;}".data(using: .utf8),
            attributes: nil
        )
    }

    /// Expected `history.compile` content when the mocked xccc called for given arguments
    private func expectedCompileHistoryContent(arguments: [String]) throws -> Data {
        let args = [Self.command] + arguments
        var data = Data()
        data = try args.reduce(data) { prev, argument -> Data in
            try prev + argument.data(using: .utf8).unwrap() + Data([0])
        }
        data += try "\0\n".data(using: .utf8).unwrap()
        return data
    }
}
