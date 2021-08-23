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

/// Plugin that downloads an artifact with a suffix fileKey
class ExtraArtifactConsumerPrebuildPlugin: ArtifactConsumerPrebuildPlugin {

    private let suffix: String
    private let placeToDownload: URL
    private let network: RemoteNetworkClient

    init(extraArtifactSuffix suffix: String, placeToDownload location: URL, network: RemoteNetworkClient) {
        self.suffix = suffix
        placeToDownload = location
        self.network = network
    }

    func run(meta: MainArtifactMeta) throws {
        let extraArtifactId = meta.fileKey.appending(suffix)
        let artifactPlaceToDownload = placeToDownload.appendingPathComponent(extraArtifactId)

        try network.download(.artifact(id: extraArtifactId), to: artifactPlaceToDownload)
    }
}
