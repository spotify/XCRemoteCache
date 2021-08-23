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


/// Plugin that can extend the artifact creation phase
protocol ArtifactCreatorPlugin {

    /// Optional remapper that replaces dependencies paths
    /// Useful when a plugin modifies underlying file locations in the compilation step
    var customPathsRemapper: DependenciesRemapper? { get }

    /// Gives a chance to append extra keys to the meta type that will be uploaded to the cache server
    /// - Parameter meta: existing meta
    /// - Returns: extra dictionary that should be appended to the meta's extraKeys field
    func extraMetaKeys(_ meta: MainArtifactMeta) throws -> [String: String]

    /// Optional artifacts that should be uploaded to the remote server
    /// - Parameter main: main artifact that has been uploaded to the remote cache server
    /// - Returns: list of artifacts that should be uploaded
    func artifactToUpload(main: MainArtifactMeta) throws -> [Artifact]
}


/// Plugin that manages addons to the artifact consumption phase (in the prebuild phase)
protocol ArtifactConsumerPrebuildPlugin {
    /// Called when the artifact preparation phase happens. Intended to download all companion artifacts uploaded
    /// from the `artifactToUpload` returned items
    /// - Parameter meta: main artifact meta
    func run(meta: MainArtifactMeta) throws
}

/// Plugin that manages addons to the artifact consumption phase (in the postbuild phase)
protocol ArtifactConsumerPostbuildPlugin {
    /// Called after the target has been reused from cache
    /// - Parameter meta: main artifact meta
    func run(meta: MainArtifactMeta) throws
}
