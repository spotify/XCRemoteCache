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

/// Factory that builds Swift products organizer (that can place all files in the final Derived Data location)
/// for a specific module
protocol ThinningConsumerSwiftProductsOrganizerFactory {
    /// Builds products organizer that produces swift products (swiftmodule, swiftdoc) for a given module
    /// - Parameters:
    ///  - architecture: .swiftmodule architecture to generate
    ///  (it can be an extended arch, like "x86_64-apple-ios-simulator")
    ///   - targetName: name of the target to generate
    ///   - moduleName: name of the module to generate
    ///   - artifactLocation: location of the unzipped artifact
    func build(
        architecture: String,
        targetName: String,
        moduleName: String,
        artifactLocation: URL
    ) -> SwiftProductsOrganizer
}

/// Factory that syncs swiftc products from the the unzipped artifacts and uses product generator that
/// employs hard linking to place files in the desired location
class ThinningConsumerUnzippedArtifactSwiftProductsOrganizerFactory: ThinningConsumerSwiftProductsOrganizerFactory {
    /// The base architecture - that current build is compiling. Equals $(ARCHS)
    private let arch: String
    private let productsLocationProvider: SwiftProductsLocationProvider
    private let fingerprintSyncer: FingerprintSyncer
    private let diskCopier: DiskCopier

    /// Default initializer
    /// - Parameters:
    ///   - arch: current architecture that the target is building for
    ///   - productsLocationProvider: a provider that provides swift products final location
    ///   - fingerprintSyncer: a syncer to decorate swift products with a figerprint override
    ///   - fileManager: FileManager
    init(
        arch: String,
        productsLocationProvider: SwiftProductsLocationProvider,
        fingerprintSyncer: FingerprintSyncer,
        diskCopier: DiskCopier
    ) {
        self.arch = arch
        self.productsLocationProvider = productsLocationProvider
        self.fingerprintSyncer = fingerprintSyncer
        self.diskCopier = diskCopier
    }

    /// Generates a swift products generator for a specific architecture and moduleName
    /// - Parameters:
    ///   - architecture: .swiftmodule architecture to generate
    ///   (it can be an extended arch, like "x86_64-apple-ios-simulator")
    ///   - targetName: target name to generate
    ///   - moduleName: swiftmodule name
    private func buildGenerator(architecture: String, targetName: String, moduleName: String) -> SwiftcProductsGenerator {
        let modulePathOutput = productsLocationProvider.swiftmoduleFileLocation(
            moduleName: moduleName,
            architecture: architecture
        )
        let objcHeaderOutput = productsLocationProvider.objcHeaderLocation(
            targetName: targetName,
            moduleName: moduleName
        )

        return ThinningDiskSwiftcProductsGenerator(
            modulePathOutput: modulePathOutput,
            objcHeaderOutput: objcHeaderOutput,
            diskCopier: diskCopier
        )
    }

    func build(
        architecture: String,
        targetName: String,
        moduleName: String,
        artifactLocation: URL
    ) -> SwiftProductsOrganizer {
        let productGenerator = buildGenerator(
            architecture: architecture,
            targetName: targetName,
            moduleName: moduleName
        )
        return UnzippedArtifactSwiftProductsOrganizer(
            arch: arch,
            moduleName: moduleName,
            artifactLocation: artifactLocation,
            productsGenerator: productGenerator,
            fingerprintSyncer: fingerprintSyncer
        )
    }
}
