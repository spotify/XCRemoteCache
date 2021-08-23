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

class ZipArtifactCreatorTests: FileXCTestCase {

    struct SimpleMeta: Meta, Equatable {
        var fileKey: String
    }

    private let sampleMeta = SimpleMeta(fileKey: "2")
    private var workingDir: URL!
    private var creator: ZipArtifactCreator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workingDir = try prepareTempDir().appendingPathComponent("creator")
        creator = ZipArtifactCreator(workingDir: workingDir, fileManager: fileManager)
    }

    func testCreatingArtifactGeneratesValidArtifactId() throws {
        let artifact = try creator.createArtifact(zipContent: [], artifactKey: "1", meta: sampleMeta)

        XCTAssertEqual(artifact.id, "1")
    }

    func testCreatingArtifactGeneratesMeta() throws {
        let artifact = try creator.createArtifact(zipContent: [], artifactKey: "1", meta: sampleMeta)

        let parsedMeta = try JSONDecoder().decode(SimpleMeta.self, from: Data(contentsOf: artifact.meta))
        XCTAssertEqual(parsedMeta, sampleMeta)
    }

    func testCreatingArtifactContainsContentAndMetaFiles() throws {
        let sampleFile = try fileManager.spt_createEmptyFile(prepareTempDir().appendingPathComponent("file.a"))

        let artifact = try creator.createArtifact(zipContent: [sampleFile], artifactKey: "1", meta: sampleMeta)

        let unzippedURL = try prepareTempDir().appendingPathComponent("unzipped")
        try Zip.unzipFile(artifact.package, destination: unzippedURL, overwrite: true, password: nil, progress: nil)
        let allFiles = try fileManager.spt_allFilesRecusively(unzippedURL)
        XCTAssertEqual(Set(allFiles), [
            unzippedURL.appendingPathComponent("file.a"),
            unzippedURL.appendingPathComponent("2.json"),
        ])
    }
}
