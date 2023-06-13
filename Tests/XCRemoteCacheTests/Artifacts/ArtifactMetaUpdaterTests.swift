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

class ArtifactMetaUpdaterTests: XCTestCase {
    private let accessorFake = FileAccessorFake(mode: .normal)
    private var metaWriter: MetaWriter!
    private var fileRemapper: FileDependenciesRemapper!
    private var updater: ArtifactMetaUpdater!
    private let sampleMeta = MainArtifactMeta(
        dependencies: [],
        fileKey: "abc",
        rawFingerprint: "",
        generationCommit: "",
        targetName: "",
        configuration: "",
        platform: "",
        xcode: "",
        inputs: ["$(BASE)/myFile.swift"],
        pluginsKeys: [:]
    )

    override func setUp() async throws {
        metaWriter = JsonMetaWriter(
            fileWriter: accessorFake,
            pretty: true
        )
        fileRemapper = TextFileDependenciesRemapper(
            remapper: StringDependenciesRemapper(
                mappings: [
                    .init(generic: "$(BASE)", local: "/base")
                ]
            ),
            fileAccessor: accessorFake
        )
        updater = ArtifactMetaUpdater(
            fileRemapper: fileRemapper,
            metaWriter: metaWriter
        )
    }

    func testStoresInTheRawArtifact() throws {
        try updater.process(rawArtifact: "/artifact")
        try updater.run(meta: sampleMeta)

        XCTAssertTrue(accessorFake.fileExists(atPath: "/artifact/abc.json"))
    }

    func testRewirtesMetaPaths() throws {
        try updater.process(rawArtifact: "/artifact")
        try updater.run(meta: sampleMeta)

        let diskMetaData = try XCTUnwrap(accessorFake.contents(atPath: "/artifact/abc.json"))
        let diskMeta = try JSONDecoder().decode(MainArtifactMeta.self, from: diskMetaData)
        XCTAssertEqual(diskMeta.inputs, ["/base/myFile.swift"])
    }

    func testFailsIfProcessorTriggerIsNotCalledBeforeRunningAPlugin() throws {
        XCTAssertThrowsError(try updater.run(meta: sampleMeta)) { error in
            switch error {
            case ArtifactMetaUpdaterError.artifactLocationIsUnknown: break
            default:
                XCTFail("Not expected error")
            }
        }
    }
}
