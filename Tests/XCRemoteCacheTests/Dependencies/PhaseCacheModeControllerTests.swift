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

class PhaseCacheModeControllerTests: XCTestCase {
    private let sampleURL = URL(fileURLWithPath: "")

    func testDisablesForSpecifiedSha() {
        let dependenciesReader = DependenciesReaderFake(dependencies: ["skipForSha": ["dbd123"]])
        let modeController = PhaseCacheModeController(
            tempDir: sampleURL,
            mergeCommitFile: sampleURL,
            phaseDependencyPath: "",
            markerPath: "",
            forceCached: false,
            dependenciesWriter: FileDependenciesWriter.init,
            dependenciesReader: { _, _ in dependenciesReader },
            markerWriter: FileMarkerWriter.init,
            llbuildLockFile: "/file",
            fileManager: FileManager.default
        )

        XCTAssertTrue(modeController.shouldDisable(for: .available(commit: "dbd123")))
    }

    func testDoesntDisableForOtherSha() {
        let dependenciesReader = DependenciesReaderFake(dependencies: ["skipForSha": ["SomeOtherSha"]])
        let modeController = PhaseCacheModeController(
            tempDir: sampleURL,
            mergeCommitFile: sampleURL,
            phaseDependencyPath: "",
            markerPath: "",
            forceCached: false,
            dependenciesWriter: FileDependenciesWriter.init,
            dependenciesReader: { _, _ in dependenciesReader },
            markerWriter: FileMarkerWriter.init,
            llbuildLockFile: "/tmp/lock",
            fileManager: FileManager.default
        )

        XCTAssertFalse(modeController.shouldDisable(for: .available(commit: "dbd123")))
    }

    func testDoesntDisableForStandardDepepdencyFormat() {
        let dependenciesReader = DependenciesReaderFake(dependencies: ["file1": ["someDependency"]])
        let modeController = PhaseCacheModeController(
            tempDir: sampleURL,
            mergeCommitFile: sampleURL,
            phaseDependencyPath: "",
            markerPath: "",
            forceCached: false,
            dependenciesWriter: FileDependenciesWriter.init,
            dependenciesReader: { _, _ in dependenciesReader },
            markerWriter: FileMarkerWriter.init,
            llbuildLockFile: "/tmp/lock",
            fileManager: FileManager.default
        )

        XCTAssertFalse(modeController.shouldDisable(for: .available(commit: "dbd123")))
    }

    func testDependsOnXcodeSelectLinkWhenEnabled() throws {
        let dependenciesWriter = DependenciesWriterSpy()
        let modeController = PhaseCacheModeController(
            tempDir: sampleURL,
            mergeCommitFile: sampleURL,
            phaseDependencyPath: "",
            markerPath: "maker",
            forceCached: false,
            dependenciesWriter: { _, _ in dependenciesWriter },
            dependenciesReader: { _, _ in DependenciesReaderFake(dependencies: [:]) },
            markerWriter: { _, _ in MarkerWriterSpy() },
            llbuildLockFile: "/tmp/lock",
            fileManager: FileManager.default
        )

        try modeController.enable(allowedInputFiles: [], dependencies: [])

        let allDeps = try dependenciesWriter.wroteDependencies.unwrap().values.flatMap { $0 }
        XCTAssertTrue(allDeps.contains("/var/db/xcode_select_link"))
    }

    func testDependsOnXcodeSelectLinkWhenDisabled() throws {
        let dependenciesWriter = DependenciesWriterSpy()
        let modeController = PhaseCacheModeController(
            tempDir: sampleURL,
            mergeCommitFile: sampleURL,
            phaseDependencyPath: "",
            markerPath: "maker",
            forceCached: false,
            dependenciesWriter: { _, _ in dependenciesWriter },
            dependenciesReader: { _, _ in DependenciesReaderFake(dependencies: [:]) },
            markerWriter: { _, _ in MarkerWriterSpy() },
            llbuildLockFile: "/tmp/lock",
            fileManager: FileManager.default
        )

        try modeController.disable()

        let allDeps = try dependenciesWriter.wroteDependencies.unwrap().values.flatMap { $0 }
        XCTAssertTrue(allDeps.contains("/var/db/xcode_select_link"))
    }

    func testForcedCachedPhaseFailToDisable() throws {
        let markerWriter = MarkerWriterSpy()
        let modeController = PhaseCacheModeController(
            tempDir: sampleURL,
            mergeCommitFile: sampleURL,
            phaseDependencyPath: "",
            markerPath: "maker",
            forceCached: true,
            dependenciesWriter: { _, _ in DependenciesWriterSpy() },
            dependenciesReader: { _, _ in DependenciesReaderFake(dependencies: [:]) },
            markerWriter: { _, _ in markerWriter },
            llbuildLockFile: "/tmp/lock",
            fileManager: FileManager.default
        )

        XCTAssertThrowsError(try modeController.disable())
        XCTAssertEqual(markerWriter.state, .initial)
    }

    func testShouldDisableWhenRemoteCacheCommitIsUnavailable() throws {
        let modeController = PhaseCacheModeController(
            tempDir: sampleURL,
            mergeCommitFile: sampleURL,
            phaseDependencyPath: "",
            markerPath: "maker",
            forceCached: false,
            dependenciesWriter: { _, _ in DependenciesWriterSpy() },
            dependenciesReader: { _, _ in DependenciesReaderFake(dependencies: [:]) },
            markerWriter: { _, _ in MarkerWriterSpy() },
            llbuildLockFile: "/tmp/lock",
            fileManager: FileManager.default
        )

        XCTAssertEqual(modeController.shouldDisable(for: .unavailable), true)
    }

    func testCreatesMarkerContent() throws {
        let compilationURL = sampleURL.appendingPathComponent("file.swift")
        let markerURL = sampleURL.appendingPathComponent("marker")
        let expectedMarkerFiles: Set = [PhaseCacheModeController.xcodeSelectLink, markerURL, compilationURL]
        let dependenciesWriter = DependenciesWriterSpy()
        let markerWriterSpy = MarkerWriterSpy()
        let modeController = PhaseCacheModeController(
            tempDir: sampleURL,
            mergeCommitFile: sampleURL,
            phaseDependencyPath: "",
            markerPath: "marker",
            forceCached: false,
            dependenciesWriter: { _, _ in dependenciesWriter },
            dependenciesReader: { _, _ in DependenciesReaderFake(dependencies: [:]) },
            markerWriter: { _, _ in markerWriterSpy },
            llbuildLockFile: "/tmp/lock",
            fileManager: FileManager.default
        )

        try modeController.enable(allowedInputFiles: [compilationURL], dependencies: [compilationURL])

        guard case .enabled(let deps) = markerWriterSpy.state else {
            XCTFail("Not expected marker state")
            return
        }
        XCTAssertEqual(Set(deps), expectedMarkerFiles)
    }
}
