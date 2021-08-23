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

enum ThinningConsumerPostbuildPluginError: Error {
    /// The aggregation target meta misses a filekey for targets
    case missingArtifactKey(targetNames: [String])
    /// The unzipped artifact is malformed. Is misses a binary file in a root directory
    case missingBinaryForArtifact(artifact: URL)
    /// Postbuild of some target(s) failed (potentially the unzipped artifacts is broken)
    case failed(underlyingErrors: [Error])
}

/// Plugin that performs "postbuild" action for all thinned targets - moves binaries, swift products, decorates with
/// fingerprint overrides etc
class ThinningConsumerPostbuildPlugin: ThinningConsumerPlugin, ArtifactConsumerPostbuildPlugin {

    private let targetTempDirsRoot: URL
    private let builtProductsDir: URL
    private let productModuleName: String
    private let arch: String
    private let thinnedTargets: [String]
    private let artifactOrganizerFactory: ThinningConsumerArtifactsOrganizerFactory
    private let swiftProductOrganizerFactory: ThinningConsumerSwiftProductsOrganizerFactory
    private let diskCopier: DiskCopier
    private let artifactInspector: ArtifactInspector
    private let swiftProductsArchitecturesRecognizer: SwiftProductsArchitecturesRecognizer
    private let worker: Worker

    init(
        targetTempDir: URL,
        builtProductsDir: URL,
        productModuleName: String,
        arch: String,
        thinnedTargets: [String],
        artifactOrganizerFactory: ThinningConsumerArtifactsOrganizerFactory,
        swiftProductOrganizerFactory: ThinningConsumerSwiftProductsOrganizerFactory,
        artifactInspector: ArtifactInspector,
        swiftProductsArchitecturesRecognizer: SwiftProductsArchitecturesRecognizer,
        diskCopier: DiskCopier,
        worker: Worker
    ) {
        targetTempDirsRoot = targetTempDir.deletingLastPathComponent()
        self.builtProductsDir = builtProductsDir
        self.productModuleName = productModuleName
        self.arch = arch
        self.thinnedTargets = thinnedTargets
        self.artifactOrganizerFactory = artifactOrganizerFactory
        self.swiftProductOrganizerFactory = swiftProductOrganizerFactory
        self.artifactInspector = artifactInspector
        self.swiftProductsArchitecturesRecognizer = swiftProductsArchitecturesRecognizer
        self.diskCopier = diskCopier
        self.worker = worker
    }

    /// Performs the core part of the postbuild phase for a single thinned target
    /// - Parameters:
    ///   - targetName: Name of the target
    ///   - productArchs: all architectures that should swift products
    ///   should be generated in DerivedData's 'Products' dir
    ///   - fileKey: fileKey that describes the artifact
    private func performPostbuildFor(targetName: String, productArchs archs: [String], fileKey: String) throws {
        // move all downloaded in prebuild phase
        // headers+binaries+swiftmodule(s) to the corresponding `targetName` directory
        let targetTempDir = targetTempDirsRoot.appendingPathComponent("\(targetName).build")
        let artifactOrganizer = artifactOrganizerFactory.build(targetTempDir: targetTempDir)
        let artifactLocation = artifactOrganizer.getActiveArtifactLocation()

        // Move cached binary artifacts to the product dir
        let binaryProducts = try artifactInspector.findBinaryProducts(fromArtifact: artifactLocation)
        guard !binaryProducts.isEmpty else {
            throw ThinningConsumerPostbuildPluginError.missingBinaryForArtifact(artifact: artifactLocation)
        }
        try binaryProducts.compactMap { $0 }.forEach { product in
            try diskCopier.copy(file: product, directory: builtProductsDir)
        }

        // Move Swift module definitions
        guard
            let moduleName = try artifactInspector.recognizeModuleName(fromArtifact: artifactLocation, arch: arch)
            else {
                /// Skip targets without swiftmodules (e.g. ObjC targets)
                return
        }

        // Swiftmodules in an artifact are cached from the "swiftc" step. Xcode along moving the swiftmodule files
        // to the builtProductsDir, duplicates the swiftmodule definition for extra archs
        // (e.g. "x86_64" -> ["x86_64, "x86_64-apple-ios-simulator"])
        for arch in archs {
            let productsOrganizer = swiftProductOrganizerFactory.build(
                architecture: arch,
                targetName: targetName,
                moduleName: moduleName,
                artifactLocation: artifactLocation
            )
            /// fileKey is equivalent of the fingerprint
            try productsOrganizer.syncProducts(fingerprint: fileKey)
        }
    }

    func run(meta: MainArtifactMeta) throws {
        onRun()
        // iterate all thinned targetName temp dirs and perform postbuild action
        let allCachedTargetFileKeys = ThinningPlugin.extractAllProductArtifacts(meta: meta)
        let thinnedTargetFileKeys = allCachedTargetFileKeys.filter { targetName, _ in
            thinnedTargets.contains(targetName)
        }
        // Ensure all thinned targets keys are available in a meta
        // (This is a second safety-net for. The same validation is done in the prebuild phase)
        let missedThinnedTargets = Set(thinnedTargets).subtracting(Set(thinnedTargetFileKeys.keys))
        guard missedThinnedTargets.isEmpty else {
            let targetNames = Array(missedThinnedTargets)
            let rawError = ThinningConsumerPostbuildPluginError.missingArtifactKey(targetNames: targetNames)
            // Thin project requires all artifacts to be available locally - has to fail immediately
            throw PluginError.unrecoverableError(rawError)
        }
        let archs = try swiftProductsArchitecturesRecognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: productModuleName
        )

        for (targetName, fileKey) in thinnedTargetFileKeys {
            worker.appendAction {
                try self.performPostbuildFor(targetName: targetName, productArchs: archs, fileKey: fileKey)
            }
        }
        if case .errors(let errors) = worker.waitForResult() {
            let rawError = ThinningConsumerPostbuildPluginError.failed(underlyingErrors: errors)
            // Thin project requires all artifacts to be available locally - has to fail immediately
            throw PluginError.unrecoverableError(rawError)
        }
    }
}
