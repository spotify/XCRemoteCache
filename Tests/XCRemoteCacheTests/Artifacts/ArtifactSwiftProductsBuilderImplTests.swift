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

class ArtifactSwiftProductsBuilderImplTests: FileXCTestCase {
    private var rootDir: URL!
    private var moduleDir: URL!
    private var swiftmoduleFile: URL!
    private var swiftmoduleDocFile: URL!
    private var swiftmoduleSourceInfoFile: URL!
    private var swiftmoduleInterfaceFile: URL!
    private var workingDir: URL!
    private var builder: ArtifactSwiftProductsBuilderImpl!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let rootDir = try prepareTempDir()
        moduleDir = rootDir.appendingPathComponent("Products")
        swiftmoduleFile = moduleDir.appendingPathComponent("MyModule.swiftmodule")
        swiftmoduleDocFile = moduleDir.appendingPathComponent("MyModule.swiftdoc")
        swiftmoduleSourceInfoFile = moduleDir.appendingPathComponent("MyModule.swiftsourceinfo")
        swiftmoduleInterfaceFile = moduleDir.appendingPathComponent("MyModule.swiftinterface")
        workingDir = rootDir.appendingPathComponent("working")
        builder = ArtifactSwiftProductsBuilderImpl(
            workingDir: workingDir,
            moduleName: "MyModule",
            fileManager: .default
        )
    }

    func testIncludesRequiredSwiftmoduleFiles() throws {
        try fileManager.spt_createFile(swiftmoduleFile, content: "swiftmodule")
        try fileManager.spt_createFile(swiftmoduleDocFile, content: "swiftdoc")
        let builderSwiftmoduleDir =
            builder
                .buildingArtifactSwiftModulesLocation()
                .appendingPathComponent("arm64")
        let expectedBuildedSwiftmoduleFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftmodule")
        let expectedBuildedSwiftmoduledocFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftdoc")

        try builder.includeModuleDefinitionsToTheArtifact(arch: "arm64", moduleURL: swiftmoduleFile)

        XCTAssertEqual(
            fileManager.contents(atPath: expectedBuildedSwiftmoduleFile.path),
            "swiftmodule".data(using: .utf8)
        )
        XCTAssertEqual(
            fileManager.contents(atPath: expectedBuildedSwiftmoduledocFile.path),
            "swiftdoc".data(using: .utf8)
        )
    }

    func testIncludesAllBasicSwiftmoduleFiles() throws {
        try fileManager.spt_createEmptyFile(swiftmoduleFile)
        try fileManager.spt_createEmptyFile(swiftmoduleDocFile)
        try fileManager.spt_createEmptyFile(swiftmoduleSourceInfoFile)
        let builderSwiftmoduleDir =
            builder
                .buildingArtifactSwiftModulesLocation()
                .appendingPathComponent("arm64")
        let expectedBuildedSwiftmoduleFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftmodule")
        let expectedBuildedSwiftmoduledocFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftdoc")
        let expectedBuildedSwiftSourceInfoFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftsourceinfo")

        try builder.includeModuleDefinitionsToTheArtifact(arch: "arm64", moduleURL: swiftmoduleFile)

        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftmoduleFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftmoduledocFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftSourceInfoFile.path))
    }

    func testIncludesAllEvolutionEnabledSwiftmoduleFiles() throws {
        try fileManager.spt_createEmptyFile(swiftmoduleFile)
        try fileManager.spt_createEmptyFile(swiftmoduleDocFile)
        try fileManager.spt_createEmptyFile(swiftmoduleSourceInfoFile)
        try fileManager.spt_createEmptyFile(swiftmoduleInterfaceFile)
        let builderSwiftmoduleDir =
            builder
                .buildingArtifactSwiftModulesLocation()
                .appendingPathComponent("arm64")
        let expectedBuildedSwiftmoduleFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftmodule")
        let expectedBuildedSwiftmoduledocFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftdoc")
        let expectedBuildedSwiftSourceInfoFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftsourceinfo")
        let expectedBuildedSwiftInterfaceFile =
            builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftinterface")

        try builder.includeModuleDefinitionsToTheArtifact(arch: "arm64", moduleURL: swiftmoduleFile)

        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftmoduleFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftmoduledocFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftSourceInfoFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftInterfaceFile.path))
    }

    func testFailsIncludingWhenMissingRequiredSwiftmoduleFiles() throws {
        XCTAssertThrowsError(
            try builder.includeModuleDefinitionsToTheArtifact(
                arch: "arm64",
                moduleURL: swiftmoduleFile
            )
        )
    }
}
