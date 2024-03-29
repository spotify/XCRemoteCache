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

/// Factory to create `ArtifactOrganizer`
protocol ThinningConsumerArtifactsOrganizerFactory {
    /// Builds artifacts aggregator that oranizes artifacts in a dedicated target temp dir
    /// - Parameter targetTempDir: location where should the organizer organize the artifact ($TARGET_TEMP_DIR)
    func build(targetTempDir: URL) -> ArtifactOrganizer
}

class ThinningConsumerZipArtifactsOrganizerFactory: ThinningConsumerArtifactsOrganizerFactory {
    private let processors: [ArtifactProcessor]
    private let fileManager: FileManager

    init(processors: [ArtifactProcessor], fileManager: FileManager) {
        self.processors = processors
        self.fileManager = fileManager
    }

    func build(targetTempDir: URL) -> ArtifactOrganizer {
        ZipArtifactOrganizer(
            targetTempDir: targetTempDir,
            artifactProcessors: processors,
            fileManager: fileManager
        )
    }
}
