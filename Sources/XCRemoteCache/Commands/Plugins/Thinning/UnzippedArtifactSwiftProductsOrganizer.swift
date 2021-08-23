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

/// Moves all swift products files from the artifact to the products dir and generate fingerprint overrides
/// In a standard flow, moving all files is done automatically by Xcode, but for a thinning flow,
/// we need to put all .swiftmodule, .swiftdoc to the desired location in DerivedData's Products location manually
protocol SwiftProductsOrganizer {
    func syncProducts(fingerprint: String) throws
}

/// Swift products organizer that generates swift products from an unzipped artifact
class UnzippedArtifactSwiftProductsOrganizer: SwiftProductsOrganizer {
    private let arch: String
    private let moduleName: String
    private let artifactLocation: URL
    private let productsGenerator: SwiftcProductsGenerator
    private let fingerprintSyncer: FingerprintSyncer

    /// Default initializer
    /// - Parameters:
    ///   - arch: the architecture for which the the artifact was generated
    ///   - moduleName: name of the module
    ///   - artifactLocation: a location of the prepared(unzipped) artifact
    ///   - productsGenerator: a generator that will move files to the desired location
    ///   - fingerprintSyncer: a syncer to decorate swift products with a figerprint override
    init(
        arch: String,
        moduleName: String,
        artifactLocation: URL,
        productsGenerator: SwiftcProductsGenerator,
        fingerprintSyncer: FingerprintSyncer
    ) {
        self.arch = arch
        self.moduleName = moduleName
        self.artifactLocation = artifactLocation
        self.productsGenerator = productsGenerator
        self.fingerprintSyncer = fingerprintSyncer
    }

    func syncProducts(fingerprint: String) throws {
        // Zipped artifact contains *.swiftmodule file placed in "swiftmodule/{{arch}}/{{moduleName}}.swiftmodule"
        let artifactSwiftmoduleDir = artifactLocation.appendingPathComponent("swiftmodule").appendingPathComponent(arch)
        let artifactSwiftmoduleBase = artifactSwiftmoduleDir.appendingPathComponent(moduleName)
        let artifactSwiftmoduleFiles = Dictionary(
            uniqueKeysWithValues: SwiftmoduleFileExtension.SwiftmoduleExtensions
                .map { ext, _ in
                    (ext, artifactSwiftmoduleBase.appendingPathExtension(ext.rawValue))
                }
        )

        // -Swift.h is placed in "include/{{arch}}/{{moduleName}}/{{moduleName}-Swift.h" location
        let artifactSwiftModuleObjCFile = artifactLocation
            .appendingPathComponent("include")
            .appendingPathComponent(arch)
            .appendingPathComponent(moduleName)
            .appendingPathComponent("\(moduleName)-Swift.h")

        let generatedModuleDir = try productsGenerator.generateFrom(
            artifactSwiftModuleFiles: artifactSwiftmoduleFiles,
            artifactSwiftModuleObjCFile: artifactSwiftModuleObjCFile
        )

        try fingerprintSyncer.decorate(sourceDir: generatedModuleDir, fingerprint: fingerprint)
    }
}
