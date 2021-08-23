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

/// Plugin that asks adding extra meta keys
class MetaAppenderArtifactCreatorPlugin: ArtifactCreatorPlugin {
    var customPathsRemapper: DependenciesRemapper?
    private let appendedKeys: [String: String]

    init(_ keys: [String: String]) {
        appendedKeys = keys
    }

    func extraMetaKeys(_ meta: MainArtifactMeta) -> [String: String] {
        return appendedKeys
    }

    func artifactToUpload(main: MainArtifactMeta) throws -> [Artifact] {
        []
    }
}

/// Plugin that asks to upload an extra artifact
class ExtraArtifactCreatorPlugin: ArtifactCreatorPlugin {
    var customPathsRemapper: DependenciesRemapper?
    private let id: String
    private let package: URL
    private let meta: URL

    init(id: String, package: URL, meta: URL) {
        self.id = id
        self.package = package
        self.meta = meta
    }

    func extraMetaKeys(_ meta: MainArtifactMeta) -> [String: String] {
        [:]
    }

    func artifactToUpload(main: MainArtifactMeta) throws -> [Artifact] {
        [Artifact(id: id, package: package, meta: meta)]
    }
}
