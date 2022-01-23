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

class BuildArtifactCreatorTests: FileXCTestCase {
    private var workDirectory: URL!
    private let sampleMeta = MainArtifactSampleMeta.defaults
    private var buildDir: URL!
    private var tempDir: URL!
    private var headerURL: URL!
    private var swiftmoduleURL: URL!
    private var swiftdocURL: URL!
    private var swiftSourceInfoURL: URL!
    private var swiftInterfaceURL: URL!
    private var executablePath: String!
    private var executableURL: URL!
    private var creator: BuildArtifactCreator!
    private var dSYM: URL!


    override func setUpWithError() throws {
        try super.setUpWithError()
        workDirectory = try prepareTempDir()

        buildDir = workDirectory.appendingPathComponent("Build")
        tempDir = workDirectory.appendingPathComponent("Temp")
        headerURL = workDirectory.appendingPathComponent("Target-Swift.h")
        swiftmoduleURL = workDirectory.appendingPathComponent("Objects-normal")
            .appendingPathComponent("Target.swiftmodule")
        swiftdocURL = workDirectory.appendingPathComponent("Objects-normal")
            .appendingPathComponent("Target.swiftdoc")
        swiftSourceInfoURL = workDirectory.appendingPathComponent("Objects-normal")
            .appendingPathComponent("Target.swiftsourceinfo")
        swiftInterfaceURL = workDirectory.appendingPathComponent("Objects-normal")
            .appendingPathComponent("Target.swiftinterface")
        executablePath = "libTarget.a"
        executableURL = buildDir.appendingPathComponent(executablePath)
        dSYM = executableURL.deletingPathExtension().appendingPathExtension(".dSYM")
        try fileManager.spt_createEmptyFile(executableURL)
        try fileManager.spt_createEmptyFile(headerURL)

        creator = BuildArtifactCreator(
            buildDir: buildDir,
            tempDir: tempDir,
            executablePath: executablePath,
            moduleName: "Target",
            modulesFolderPath: "",
            dSYMPath: dSYM,
            metaWriter: JsonMetaWriter(fileWriter: fileManager, pretty: false),
            fileManager: fileManager
        )
    }

    func testPackagesExecutableAndMeta() throws {
        let artifact = try creator.createArtifact(artifactKey: "key", meta: sampleMeta)

        let unzippedURL = workDirectory.appendingPathComponent(UUID().uuidString)
        try Zip.unzipFile(artifact.package, destination: unzippedURL, overwrite: true, password: nil, progress: nil)
        let allFiles = try fileManager.spt_allFilesRecusively(unzippedURL)
        XCTAssertEqual(Set(allFiles), [
            unzippedURL.appendingPathComponent("libTarget.a"),
            unzippedURL.appendingPathComponent("fileKey.json"),
        ])
    }

    func testPackagesObjCHeader() throws {
        try creator.includeObjCHeaderToTheArtifact(arch: "arch", headerURL: headerURL)
        let artifact = try creator.createArtifact(artifactKey: "key", meta: sampleMeta)

        let unzippedURL = workDirectory.appendingPathComponent(UUID().uuidString)
        try Zip.unzipFile(artifact.package, destination: unzippedURL, overwrite: true, password: nil, progress: nil)
        let allFiles = try fileManager.spt_allFilesRecusively(unzippedURL)
        XCTAssertEqual(Set(allFiles), [
            unzippedURL.appendingPathComponent("include/arch/Target/Target-Swift.h"),
            unzippedURL.appendingPathComponent("libTarget.a"),
            unzippedURL.appendingPathComponent("fileKey.json"),
        ])
    }

    func testPackagesSwiftmoduleFiles() throws {
        try fileManager.spt_createEmptyFile(swiftmoduleURL)
        try fileManager.spt_createEmptyFile(swiftdocURL)
        try fileManager.spt_createEmptyFile(swiftSourceInfoURL)

        try creator.includeModuleDefinitionsToTheArtifact(arch: "arch", moduleURL: swiftmoduleURL)
        let artifact = try creator.createArtifact(artifactKey: "key", meta: sampleMeta)

        let unzippedURL = workDirectory.appendingPathComponent(UUID().uuidString)
        try Zip.unzipFile(artifact.package, destination: unzippedURL, overwrite: true, password: nil, progress: nil)
        let allFiles = try fileManager.spt_allFilesRecusively(unzippedURL)
        XCTAssertEqual(Set(allFiles), [
            unzippedURL.appendingPathComponent("libTarget.a"),
            unzippedURL.appendingPathComponent("fileKey.json"),
            unzippedURL.appendingPathComponent("swiftmodule/arch/Target.swiftmodule"),
            unzippedURL.appendingPathComponent("swiftmodule/arch/Target.swiftdoc"),
            unzippedURL.appendingPathComponent("swiftmodule/arch/Target.swiftsourceinfo"),
        ])
    }

    func testPackagesEvolutionEnabledSwiftmoduleFiles() throws {
        try fileManager.spt_createEmptyFile(swiftmoduleURL)
        try fileManager.spt_createEmptyFile(swiftdocURL)
        try fileManager.spt_createEmptyFile(swiftSourceInfoURL)
        try fileManager.spt_createEmptyFile(swiftInterfaceURL)

        try creator.includeModuleDefinitionsToTheArtifact(arch: "arch", moduleURL: swiftmoduleURL)
        let artifact = try creator.createArtifact(artifactKey: "key", meta: sampleMeta)

        let unzippedURL = workDirectory.appendingPathComponent(UUID().uuidString)
        try Zip.unzipFile(artifact.package, destination: unzippedURL, overwrite: true, password: nil, progress: nil)
        let allFiles = try fileManager.spt_allFilesRecusively(unzippedURL)
        XCTAssertEqual(Set(allFiles), [
            unzippedURL.appendingPathComponent("libTarget.a"),
            unzippedURL.appendingPathComponent("fileKey.json"),
            unzippedURL.appendingPathComponent("swiftmodule/arch/Target.swiftmodule"),
            unzippedURL.appendingPathComponent("swiftmodule/arch/Target.swiftdoc"),
            unzippedURL.appendingPathComponent("swiftmodule/arch/Target.swiftsourceinfo"),
            unzippedURL.appendingPathComponent("swiftmodule/arch/Target.swiftinterface"),
        ])
    }

    func testFailsPackageWhenSwiftmoduleRelatedFilesAreMissing() throws {
        // Creating only `Target.swiftmodule`, without `.swiftdoc`
        try fileManager.spt_createEmptyFile(swiftmoduleURL)

        XCTAssertThrowsError(try creator.includeModuleDefinitionsToTheArtifact(arch: "arch", moduleURL: swiftmoduleURL))
    }

    func testIncludesAlreadyExistingDynamicLibrary() throws {
        let dirToUnzip = workDirectory.appendingPathComponent("unzip")
        let unzippedDSym = dirToUnzip.appendingPathComponent(dSYM.lastPathComponent)
        try fileManager.createDirectory(at: dirToUnzip, withIntermediateDirectories: true, attributes: nil)
        fileManager.createFile(atPath: dSYM.path, contents: nil, attributes: nil)

        let artifact = try creator.createArtifact(artifactKey: "1", meta: sampleMeta)

        try Zip.unzipFile(artifact.package, destination: dirToUnzip, overwrite: true, password: nil)
        XCTAssertTrue(fileManager.fileExists(atPath: unzippedDSym.path))
    }
}
