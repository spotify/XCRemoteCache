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

enum MetaPathProviderError: Error {
    /// Generic error when a meta path cannot be provided
    case failed(message: String)
}

protocol MetaPathProvider {
    /// Returns the location of the meta file on disk
    func getMetaPath() throws -> URL
}

/// Finds the location of the meta in the unzipped artifact.
/// Assumes the artifact contains only a single .json file:
/// a meta file with filename equal to the fileKey
class ArtifactMetaPathProvider: MetaPathProvider {
    private let artifactLocation: URL
    private let dirScanner: DirScanner

    init(
        artifactLocation: URL,
        dirScanner: DirScanner
    ) {
        self.artifactLocation = artifactLocation
        self.dirScanner = dirScanner
    }

    func getMetaPath() throws -> URL {
        let items = try dirScanner.items(at: artifactLocation)
        guard let meta = items.first(where: { $0.pathExtension == "json" }) else {
            throw MetaPathProviderError.failed(
                message: "artifact \(artifactLocation) doesn't contain expected .json with a meta"
            )
        }
        return meta
    }
}
