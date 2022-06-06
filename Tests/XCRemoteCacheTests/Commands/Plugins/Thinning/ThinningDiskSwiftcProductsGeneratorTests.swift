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

class ThinningDiskSwiftcProductsGeneratorTests: FileXCTestCase {

    func testLinksSwiftProductsToValidLocations() throws {
        let workingDir = try prepareTempDir()
        let moduleFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule.swiftmodule"),
            content: "module"
        )
        let headerFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule-Swift.h"),
            content: "header"
        )
        let docsFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule.swiftdoc"),
            content: "docs"
        )
        let sourceInfoFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule.swiftsourceinfo"),
            content: "sourceInfo"
        )
        let artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL] = [
            .swiftmodule: moduleFile,
            .swiftdoc: docsFile,
            .swiftsourceinfo: sourceInfoFile,
        ]
        let buildDir = workingDir.appendingPathComponent("build")
        let headersDir = workingDir.appendingPathComponent("headers")
        let destinationSwiftModuleDir = buildDir
            .appendingPathComponent("MyModule.swiftmodule", isDirectory: true)
        let objCHeader = headersDir
            .appendingPathComponent("MyModule-Swift.h")
        let destinationSwiftModule = destinationSwiftModuleDir
            .appendingPathComponent("arm64.swiftmodule")
        let expectedSwiftSourceInfoFile = destinationSwiftModuleDir
            .appendingPathComponent("Project")
            .appendingPathComponent("arm64.swiftsourceinfo")
        let generator = ThinningDiskSwiftcProductsGenerator(
            modulePathOutput: destinationSwiftModule,
            objcHeaderOutput: objCHeader,
            diskCopier: HardLinkDiskCopier(fileManager: .default)
        )

        let generatedModulePath = try generator.generateFrom(
            artifactSwiftModuleFiles: artifactSwiftModuleFiles,
            artifactSwiftModuleObjCFile: headerFile
        )

        XCTAssertEqual(generatedModulePath.swiftmoduleDir, destinationSwiftModuleDir)
        XCTAssertEqual(fileManager.contents(atPath: expectedSwiftSourceInfoFile.path), "sourceInfo".data(using: .utf8))
        XCTAssertEqual(fileManager.contents(atPath: objCHeader.path), "header".data(using: .utf8))
    }
}
