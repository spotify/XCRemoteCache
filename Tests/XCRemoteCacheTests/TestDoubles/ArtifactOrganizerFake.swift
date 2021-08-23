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

import Foundation
@testable import XCRemoteCache

class ArtifactOrganizerFake: ArtifactOrganizer {

    private let unzippedExtension: String
    private let artifactRoot: URL
    private var prepared: Set<String> = []
    private(set) var activated: URL?

    init(artifactRoot: URL = URL(fileURLWithPath: ""), unzippedExtension: String = "unzip") {
        self.artifactRoot = artifactRoot
        self.unzippedExtension = unzippedExtension
    }

    func prepareArtifactLocationFor(fileKey: String) throws -> ArtifactOrganizerLocationPreparationResult {
        if prepared.contains(fileKey) {
            return .artifactExists(
                artifactDir: artifactRoot.appendingPathComponent(fileKey).appendingPathExtension(unzippedExtension)
            )
        } else {
            return .preparedForArtifact(artifact: artifactRoot.appendingPathComponent(fileKey))
        }
    }

    func prepare(artifact: URL) throws -> URL {
        prepared.insert(artifact.lastPathComponent)
        return artifactRoot.appendingPathComponent(artifact.lastPathComponent).appendingPathExtension(unzippedExtension)
    }

    func getActiveArtifactLocation() -> URL {
        artifactRoot
    }

    func getActiveArtifactFilekey() throws -> RawFingerprint {
        ""
    }

    func activate(extractedArtifact: URL) throws {
        activated = extractedArtifact
    }
}
