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

enum ArtifactMetaProcessorError: Error {
    /// The prebuild plugin execution was called but the local
    /// path to the artifact directory is unknown
    /// Might happen that the artifact processor didn't invoke
    /// a request to process an artifact
    case artifactLocationIsUnknown
}

/// Processes downloaded artifact by replacing generic paths in generated ObjC headers placed in ./include
class ArtifactMetaProcessor: ArtifactProcessor {
    /// Artifact relative meta path
    static let metaLocation = "meta.json"
    private var artifactLocation: URL?
    private let metaWriter: MetaWriter

    init(metaWriter: MetaWriter) {
        self.metaWriter = metaWriter
    }
    
    /// Remembers the artifact location, used later in the plugin
    /// - Parameter url: artifact's root directory
    func process(rawArtifact url: URL) throws {
        artifactLocation = url
    }

    func process(localArtifact url: URL) throws {
        // No need to do anything in the postbuild
    }
}

extension ArtifactMetaProcessor: ArtifactConsumerPrebuildPlugin {
    /// Overrides the meta json file in the downloaded artifact
    func run(meta: MainArtifactMeta) throws {
        guard let artifactLocation = artifactLocation else {
            throw ArtifactMetaProcessorError.artifactLocationIsUnknown
        }
        let metaLocation = artifactLocation.appendingPathComponent(Self.self.metaLocation)
        _ = try metaWriter.write(meta, locationDir: metaLocation)
    }
}
