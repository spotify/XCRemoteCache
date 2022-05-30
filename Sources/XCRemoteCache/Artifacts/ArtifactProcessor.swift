// Copyright (c) 2022 Spotify AB.
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


/// Performs all process locally on a raw artifact package
/// Coule be a place for file reorganization (to support legacy package formats) and/or
/// remapp absolute paths in some package files
protocol ArtifactProcessor {
    /// Processes an artifact output in a directory
    /// - Parameter rawArtifact: directory that contains raw artifact content
    func process(rawArtifact: URL) throws
}

/// Processes downloaded artifact by replacing generic paths in generated ObjC headers placed in ./include
class DownloadedArtifactProcessor: ArtifactProcessor {
    /// All directories in an artifact that should be processed by path remapping
    private static let remappingDirs = ["include"]
    private let fileRemapper: FileDependenciesRemapper
    private let dirScanner: DirScanner

    init(fileRemapper: FileDependenciesRemapper, dirScanner: DirScanner) {
        self.fileRemapper = fileRemapper
        self.dirScanner = dirScanner
    }

    /// Replaces all generic paths in a raw artifact with a absolute paths, specific for a given
    /// machine and configuration
    /// - Parameter rawArtifact: raw artifact location
    /// - Throws: TBD
    func process(rawArtifact url: URL) throws {
        for remappingDir in Self.remappingDirs {
            let remappingPath = url.appendingPathComponent(remappingDir).path
            let allFiles = try dirScanner.items(at: URL(fileURLWithPath: remappingPath))
            try allFiles.forEach(fileRemapper.remap(fromGeneric:))
        }
    }
}

/// No-operation processor
class NoopArtifactProcessor: ArtifactProcessor {
    func process(rawArtifact url: URL) throws {}
}
