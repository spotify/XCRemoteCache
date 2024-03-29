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

import Foundation

enum ArtifactMetaUpdaterError: Error {
    /// The prebuild plugin execution was called but the local
    /// path to the artifact directory is still unknown
    /// Might happen that the artifact processor didn't invoke the updater's
    /// .process() after downloading/activating an artifact
    case artifactLocationIsUnknown
}

/// Updates the meta file in an unzipped artifact directory, by placing an up-to-date
/// and remapped meta file. Updating the meta in the artifact allows reusing existing
/// artifacts it a new meta.json schema has been released to the meta format, while
/// artifacts are still backward-compatible
class ArtifactMetaUpdater: ArtifactProcessor {
    private var artifactLocation: URL?
    private let metaWriter: MetaWriter
    private let fileRemapper: FileDependenciesRemapper

    init(
        fileRemapper: FileDependenciesRemapper,
        metaWriter: MetaWriter
    ) {
        self.metaWriter = metaWriter
        self.fileRemapper = fileRemapper
    }

    /// Remembers the artifact location, used later in the plugin
    /// - Parameter url: artifact's root directory
    func process(rawArtifact url: URL) throws {
        // Storing the location of the just downloaded/activated artifact
        // Note, the `url` location already includes a meta (generated by producer
        // while compiling and building an artifact)
        artifactLocation = url
    }

    func process(localArtifact url: URL) throws {
        // No need to do anything in the postbuild
    }
}

extension ArtifactMetaUpdater: ArtifactConsumerPrebuildPlugin {

    /// Updates the meta json file in a local, unzipped, artifact location. It also remaps
    /// all paths so other steps (like actool or postbuild) don't have to do it again
    func run(meta: MainArtifactMeta) throws {
        guard let artifactLocation = artifactLocation else {
            throw ArtifactMetaUpdaterError.artifactLocationIsUnknown
        }
        let metaURL = try metaWriter.write(meta, locationDir: artifactLocation)
        try fileRemapper.remap(fromGeneric: metaURL)
    }
}
