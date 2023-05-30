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

class SwiftcOrchestratorTests: XCTestCase {
    private let sampleURL = URL(fileURLWithPath: "")
    private let moduleOutputURL = URL(fileURLWithPath: "/SomePath/module.swiftmodule")
    private let objcHeaderURL = URL(fileURLWithPath: "/SomePath/Module-Swift.h")
    private var shellOutSpy: ShellOutSpy!
    private var artifactBuilder: ArtifactSwiftProductsBuilderSpy!
    private var invocationStorage: InvocationStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        shellOutSpy = ShellOutSpy()
        artifactBuilder = ArtifactSwiftProductsBuilderSpy(
            buildingArtifact: sampleURL,
            objcLocation: sampleURL
        )
        invocationStorage = InMemoryInvocationStorage(command: "xcswiftc")
    }

    func testForProducerModeBuildsArtifactObjCHeader() throws {
        let swiftc = SwiftcMock(mockingResult: .success)
        let orchestrator = SwiftcOrchestrator(
            mode: .producer,
            swiftc: swiftc,
            swiftcCommand: "",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "archTest",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(artifactBuilder.addedObjCHeaders, ["archTest": [objcHeaderURL]])
    }

    func testFailedMockedCompilationInProducerModeCallsSwiftc() throws {
        let swiftc = SwiftcMock(mockingResult: .forceFallback)
        let orchestrator = SwiftcOrchestrator(
            mode: .producer,
            swiftc: swiftc,
            swiftcCommand: "sampleSwiftc",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "archTest",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(shellOutSpy.calledProcesses.first?.command, "sampleSwiftc")
    }

    func testRespectsFallbackShellProcessor() throws {
        let swiftc = SwiftcMock(mockingResult: .forceFallback)
        let expectedArgs: [String] = ProcessInfo().arguments.dropFirst() + ["-v"]
        let verboseCommandProcessor = ExtraArgumentShellCommandsProcessor("-v")
        let orchestrator = SwiftcOrchestrator(
            mode: .producer,
            swiftc: swiftc,
            swiftcCommand: "swiftc",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "arch",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [verboseCommandProcessor],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(shellOutSpy.calledProcesses.first?.args, expectedArgs)
    }

    func testPostprocessesFallbackCommand() throws {
        let swiftc = SwiftcMock(mockingResult: .forceFallback)
        var postProcessed = false
        let verboseCommandProcessor = PostShellCommandsProcessor {
            postProcessed = true
        }
        let orchestrator = SwiftcOrchestrator(
            mode: .producer,
            swiftc: swiftc,
            swiftcCommand: "swiftc",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "arch",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [verboseCommandProcessor],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertTrue(postProcessed)
    }

    func testCallsPreviousInvocationsOnFallback() throws {
        let swiftc = SwiftcMock(mockingResult: .forceFallback)
        try invocationStorage.store(args: ["history1"])
        try invocationStorage.store(args: ["history2"])
        let orchestrator = SwiftcOrchestrator(
            mode: .consumer(commit: .available(commit: "1")),
            swiftc: swiftc,
            swiftcCommand: "swiftc",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "arch",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(shellOutSpy.calledProcesses, [
            .init(command: "xcswiftc", args: ["history1"], envs: ProcessInfo.processInfo.environment),
            .init(command: "xcswiftc", args: ["history2"], envs: ProcessInfo.processInfo.environment),
        ])
    }

    func testSwitchesToFallbackProcessOnForcedFallback() throws {
        let swiftc = SwiftcMock(mockingResult: .forceFallback)
        let expectedArgs = Array(ProcessInfo().arguments.dropFirst())
        let orchestrator = SwiftcOrchestrator(
            mode: .consumer(commit: .available(commit: "1")),
            swiftc: swiftc,
            swiftcCommand: "swiftc",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "arch",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(shellOutSpy.switchedProcess, .init(command: "swiftc", args: expectedArgs, envs: nil))
    }

    func testSwitchesToFallbackProcessOnDetroyedStorage() throws {
        let swiftc = SwiftcMock(mockingResult: .success)
        let orchestrator = SwiftcOrchestrator(
            mode: .consumer(commit: .available(commit: "1")),
            swiftc: swiftc,
            swiftcCommand: "swiftc",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "arch",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )
        _ = try invocationStorage.retrieveAll()

        try orchestrator.run()

        XCTAssertNotNil(shellOutSpy.switchedProcess)
    }

    func testForFailedCompilationMockInProducerFastModeBuildsArtifactObjCHeader() throws {
        let swiftc = SwiftcMock(mockingResult: .forceFallback)
        let orchestrator = SwiftcOrchestrator(
            mode: .producerFast,
            swiftc: swiftc,
            swiftcCommand: "",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "archTest",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(artifactBuilder.addedObjCHeaders, ["archTest": [objcHeaderURL]])
    }

    func testSuccessedMockInProducerFastModeDoesntFillObjCHeader() throws {
        let swiftc = SwiftcMock(mockingResult: .success)
        let orchestrator = SwiftcOrchestrator(
            mode: .producerFast,
            swiftc: swiftc,
            swiftcCommand: "",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: moduleOutputURL,
            arch: "arch",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(artifactBuilder.addedObjCHeaders, [:])
    }


    func testNotSetObjCHeaderIsNotCreated() throws {
        let swiftc = SwiftcMock(mockingResult: .success)
        let orchestrator = SwiftcOrchestrator(
            mode: .producer,
            swiftc: swiftc,
            swiftcCommand: "",
            objcHeaderOutput: nil,
            moduleOutput: moduleOutputURL,
            arch: "arch",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(artifactBuilder.addedObjCHeaders, [:])
    }

    func testNotSetModuleOutputIsNotCreated() throws {
        let swiftc = SwiftcMock(mockingResult: .success)
        let orchestrator = SwiftcOrchestrator(
            mode: .producer,
            swiftc: swiftc,
            swiftcCommand: "",
            objcHeaderOutput: objcHeaderURL,
            moduleOutput: nil,
            arch: "arch",
            artifactBuilder: artifactBuilder,
            producerFallbackCommandProcessors: [],
            invocationStorage: invocationStorage,
            shellOut: shellOutSpy
        )

        try orchestrator.run()

        XCTAssertEqual(artifactBuilder.addedModuleDefinitions, [:])
    }

}
