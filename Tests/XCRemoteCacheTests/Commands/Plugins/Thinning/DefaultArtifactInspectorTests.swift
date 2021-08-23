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

class DefaultArtifactInspectorTests: FileXCTestCase {
    private var inspector: DefaultArtifactInspector!
    private var artifact: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        artifact = try prepareTempDir().appendingPathComponent("artifact")
        inspector = DefaultArtifactInspector(dirAccessor: fileManager)
    }

    func testFindingALibrary() throws {
        let binary = artifact.appendingPathComponent("binary.a")
        try fileManager.spt_writeToFile(atPath: binary.path, contents: nil)

        let binaries = try inspector.findBinaryProducts(fromArtifact: artifact)

        let binariesWithoutSymlinks = binaries.map { $0.resolvingSymlinksInPath() }
        XCTAssertEqual(binariesWithoutSymlinks, [binary])
    }

    func testRecognizingModuleName() throws {
        let swiftmoduleDir = artifact
            .appendingPathComponent("swiftmodule")
            .appendingPathComponent("x86")
        let swiftmoduleFile = swiftmoduleDir.appendingPathComponent("MyModule.swiftmodule")
        try fileManager.spt_writeToFile(atPath: swiftmoduleFile.path, contents: nil)

        let name = try inspector.recognizeModuleName(fromArtifact: artifact, arch: "x86")

        XCTAssertEqual(name, "MyModule")
    }

    func testRecognizingNonExistingSwiftModuleAsNil() throws {
        let name = try inspector.recognizeModuleName(fromArtifact: artifact, arch: "x86")

        XCTAssertNil(name)
    }

    func testRecognizingThrowsWhenMissingSwiftmoduleFile() throws {
        let swiftmoduleDir = artifact
            .appendingPathComponent("swiftmodule")
            .appendingPathComponent("x86")
        try fileManager.spt_createEmptyDir(swiftmoduleDir)

        XCTAssertThrowsError(try inspector.recognizeModuleName(fromArtifact: artifact, arch: "x86")) { error in
            guard case ArtifactInspectorError.missingSwiftmoduleFileInArtifact(artifact: artifact) = error else {
                XCTFail("Unexpected error \(error).")
                return
            }
        }
    }
}
