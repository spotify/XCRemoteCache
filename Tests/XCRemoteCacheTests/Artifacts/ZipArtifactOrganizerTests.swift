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
import Zip

class ZipArtifactOrganizerTests: XCTestCase {

    private let fileManager = FileManager.default
    private let workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(#file)

    fileprivate func cleanupFiles() throws {
        if fileManager.fileExists(atPath: workingDirectory.path) {
            try fileManager.removeItem(at: workingDirectory)
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try cleanupFiles()
    }

    override func tearDownWithError() throws {
        try cleanupFiles()
        try super.tearDownWithError()
    }

    private func prepareZipFile(content: String, fileName: String, zipFileName: String = #function) throws -> URL {
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true, attributes: nil)
        let artifactMockURL = workingDirectory.appendingPathComponent(fileName)
        fileManager.createFile(atPath: artifactMockURL.path, contents: content.data(using: .utf8))
        let zipURL = workingDirectory.appendingPathComponent(zipFileName).appendingPathExtension("zip")
        try Zip.zipFiles(paths: [artifactMockURL], zipFilePath: zipURL, password: nil, progress: nil)
        return zipURL
    }

    func testPreparePlacesArtifactInTheActiveLocation() throws {
        let zipURL = try prepareZipFile(content: "Magic", fileName: "content.txt")
        let organizer = ZipArtifactOrganizer(
            targetTempDir: workingDirectory,
            artifactProcessors: [],
            fileManager: fileManager
        )

        let preparedArtifact = try organizer.prepare(artifact: zipURL)

        let preparedFile = preparedArtifact.appendingPathComponent("content.txt")
        try XCTAssertEqual(String(contentsOf: preparedFile), "Magic")
    }

    func testPreparingExistingArtifact() throws {
        let zipURL = try prepareZipFile(content: "Magic", fileName: "content.txt")
        let organizer = ZipArtifactOrganizer(
            targetTempDir: workingDirectory,
            artifactProcessors: [],
            fileManager: fileManager
        )

        _ = try organizer.prepare(artifact: zipURL)
        let preparedArtifact = try organizer.prepare(artifact: zipURL)

        let preparedFile = preparedArtifact.appendingPathComponent("content.txt")
        try XCTAssertEqual(String(contentsOf: preparedFile), "Magic")
    }

    func testPreparePlacesArtifactInTheFileKeyRelatedLocation() throws {
        let zipURL = try prepareZipFile(content: "Magic", fileName: "content.txt", zipFileName: "abb32_fileKey")
        let organizer = ZipArtifactOrganizer(
            targetTempDir: workingDirectory,
            artifactProcessors: [],
            fileManager: fileManager
        )
        let expectedArtifactLocation = workingDirectory.appendingPathComponent("abb32_fileKey")

        let preparedArtifact = try organizer.prepare(artifact: zipURL)

        XCTAssertEqual(preparedArtifact, expectedArtifactLocation)
    }

    func testPrepareArtifactLocationTriesToReuseExistingFileKeyArtifact() throws {
        let sampleFileKey = "aba646"
        // All files downloaded by XCRemoteCache are wrapped withing `xccache` directory
        let artifactLocation = workingDirectory.appendingPathComponent("xccache")
            .appendingPathComponent(sampleFileKey, isDirectory: true)
        try fileManager.createDirectory(at: artifactLocation, withIntermediateDirectories: true, attributes: nil)
        let organizer = ZipArtifactOrganizer(
            targetTempDir: workingDirectory,
            artifactProcessors: [],
            fileManager: fileManager
        )

        let result = try organizer.prepareArtifactLocationFor(fileKey: sampleFileKey)
        if case .artifactExists(artifactDir: let u) = result {
            XCTAssertEqual(u.path, artifactLocation.path)
        }
        XCTAssertEqual(result, .artifactExists(artifactDir: artifactLocation))
    }

    func testCreatesArtifactLocationAccordingToFileKey() throws {
        let sampleFileKey = "aba646"
        // All files downloaded by XCRemoteCache are wrapped withing `xccache` directory
        let artifactLocation = workingDirectory
            .appendingPathComponent("xccache")
            .appendingPathComponent(sampleFileKey)
            .appendingPathExtension("zip")
        let organizer = ZipArtifactOrganizer(
            targetTempDir: workingDirectory,
            artifactProcessors: [],
            fileManager: fileManager
        )

        let result = try organizer.prepareArtifactLocationFor(fileKey: sampleFileKey)

        XCTAssertEqual(result, .preparedForArtifact(artifact: artifactLocation))
    }

    func testFindsAritfactFilekeyFromSymbolicLink() throws {
        let expectedFileKey = "abc123"
        // Setting up a disk directories structure:
        // `workingDirectory`
        //  | - xccache
        //      | - "abc123"
        //      | - "active" (^ symbolic link to "abc123")
        let xccache = workingDirectory.appendingPathComponent("xccache")
        let activeLink = xccache.appendingPathComponent("active")
        let activeArtifact = workingDirectory.appendingPathComponent(expectedFileKey)
        try fileManager.createDirectory(at: xccache, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: activeArtifact, withIntermediateDirectories: true, attributes: nil)
        try fileManager.spt_forceSymbolicLink(at: activeLink, withDestinationURL: activeArtifact)

        let organizer = ZipArtifactOrganizer(
            targetTempDir: workingDirectory,
            artifactProcessors: [],
            fileManager: fileManager
        )

        let fileKey = try organizer.getActiveArtifactFilekey()

        XCTAssertEqual(fileKey, expectedFileKey)
    }

    func testPrepareRunsProcessorsForAlreadyExistingArtifacts() throws {
        let zipURL = try prepareZipFile(content: "Magic", fileName: "content.txt")
        let artifactURL = zipURL.deletingPathExtension()
        let processor = DestroyerArtifactProcessor(fileManager)
        let organizer: ZipArtifactOrganizer = ZipArtifactOrganizer(
            targetTempDir: workingDirectory,
            artifactProcessors: [processor],
            fileManager: fileManager
        )
        try fileManager.createDirectory(
            at: artifactURL,
            withIntermediateDirectories: true
        )

        let preparedArtifact = try organizer.prepare(artifact: zipURL)

        XCTAssertFalse(fileManager.fileExists(atPath: preparedArtifact.path))

    }

    func testPrepareRunsProcessorsForNewlyUnzippedArtifacts() throws {
        let zipURL = try prepareZipFile(content: "Magic", fileName: "content.txt")
        let processor = DestroyerArtifactProcessor(fileManager)
        let organizer: ZipArtifactOrganizer = ZipArtifactOrganizer(
            targetTempDir: workingDirectory,
            artifactProcessors: [processor],
            fileManager: fileManager
        )

        let preparedArtifact = try organizer.prepare(artifact: zipURL)

        XCTAssertFalse(fileManager.fileExists(atPath: preparedArtifact.path))
    }

}
