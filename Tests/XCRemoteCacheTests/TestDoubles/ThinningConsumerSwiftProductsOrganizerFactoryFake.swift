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

@testable import XCRemoteCache
import XCTest

class ThinningConsumerSwiftProductsOrganizerFactoryFake: ThinningConsumerSwiftProductsOrganizerFactory {
    private let arch: String
    private let generator: SwiftcProductsGenerator
    private let syncer: FingerprintSyncer

    init(arch: String, generator: SwiftcProductsGenerator, syncer: FingerprintSyncer) {
        self.arch = arch
        self.generator = generator
        self.syncer = syncer
    }

    func build(architecture: String, targetName: String, moduleName: String, artifactLocation: URL) -> SwiftProductsOrganizer {
        return UnzippedArtifactSwiftProductsOrganizer(
            arch: arch,
            moduleName: moduleName,
            artifactLocation: artifactLocation,
            productsGenerator: generator,
            fingerprintSyncer: syncer
        )
    }
}
