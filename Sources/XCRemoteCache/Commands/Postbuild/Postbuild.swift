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

enum PostbuildError: Error {
    /// Called when trying to perform the postbuild even the remote cache is disabled
    case disabledCache
}

/// Performs postbuilds actions:
/// * copies fingerprint overrides from a cache or generates these if a target was built from sources
/// * uploads an artifact to the remote server (if the producer mode is ON)
class Postbuild {
    private let context: PostbuildContext
    private let networkClient: RemoteNetworkClient
    private let remapper: DependenciesRemapper
    private let fingerprintAccumulator: ContextAwareFingerprintAccumulator
    private let artifactsOrganizer: ArtifactOrganizer
    private let artifactCreator: ArtifactCreator
    private let fingerprintSyncer: FingerprintSyncer
    private let dependenciesReader: DependenciesReader
    private let dependencyProcessor: DependencyProcessor
    private let fingerprintOverrideManager: FingerprintOverrideManager
    private let dSYMOrganizer: DSYMOrganizer
    private let modeController: CacheModeController
    private let metaReader: MetaReader
    private let metaWriter: MetaWriter
    private let creatorPlugins: [ArtifactCreatorPlugin]
    private let consumerPlugins: [ArtifactConsumerPostbuildPlugin]

    init(
        context: PostbuildContext,
        networkClient: RemoteNetworkClient,
        remapper: DependenciesRemapper,
        fingerprintAccumulator: ContextAwareFingerprintAccumulator,
        artifactsOrganizer: ArtifactOrganizer,
        artifactCreator: ArtifactCreator,
        fingerprintSyncer: FingerprintSyncer,
        dependenciesReader: DependenciesReader,
        dependencyProcessor: DependencyProcessor,
        fingerprintOverrideManager: FingerprintOverrideManager,
        dSYMOrganizer: DSYMOrganizer,
        modeController: CacheModeController,
        metaReader: MetaReader,
        metaWriter: MetaWriter,
        creatorPlugins: [ArtifactCreatorPlugin],
        consumerPlugins: [ArtifactConsumerPostbuildPlugin]
    ) {
        self.context = context
        self.networkClient = networkClient
        self.remapper = remapper
        self.fingerprintAccumulator = fingerprintAccumulator
        self.artifactsOrganizer = artifactsOrganizer
        self.artifactCreator = artifactCreator
        self.fingerprintSyncer = fingerprintSyncer
        self.dependenciesReader = dependenciesReader
        self.dependencyProcessor = dependencyProcessor
        self.fingerprintOverrideManager = fingerprintOverrideManager
        self.dSYMOrganizer = dSYMOrganizer
        self.modeController = modeController
        self.metaReader = metaReader
        self.metaWriter = metaWriter
        self.creatorPlugins = creatorPlugins
        self.consumerPlugins = consumerPlugins
    }

    private func readMeta() throws -> MainArtifactMeta {
        guard case .available(commit: let remoteCommit) = context.remoteCommit else {
            throw PostbuildError.disabledCache
        }
        // Fetch meta from remote side - it should already be in the local cache, triggered by prebuild
        let metaData = try networkClient.fetch(.meta(commit: remoteCommit))
        return try metaReader.read(data: metaData)
    }

    /// Performs all extra actions for the consumer scenario
    /// 1. Moves all fingerprint overrides from a cache dir to the product location
    /// 2. Moves all optional dSYMs to the product location
    public func performBuildCompletion() throws {
        // artifact filekey is equivalent to context specific fingerprint of its content
        let contextSpecificFingerprint = try artifactsOrganizer.getActiveArtifactFilekey()
        try generateFingerprintOverrides(contextSpecificFingerprint: contextSpecificFingerprint)
        let localArtifactLocation = artifactsOrganizer.getActiveArtifactLocation()
        try dSYMOrganizer.syncDSYM(artifactPath: localArtifactLocation)

        // Call consumer plugins (if any)
        guard !consumerPlugins.isEmpty else {
            // quit early to not unnecessary generate meta struct
            return
        }
        let meta = try readMeta()
        try consumerPlugins.forEach { plugin in
            try plugin.run(meta: meta)
        }
    }

    public func performBuildCleanup() throws {
        try dSYMOrganizer.cleanup()
    }

    /// Deletes fingerprint overrides (if already set)
    public func deleteFingerprintOverrides() throws {
        try generateFingerprintOverrides(contextSpecificFingerprint: nil)
    }

    /// Generates fingerprint overrides in the target product location, based on all files used in the compilation
    public func generateFingerprintOverrides() throws {
        // Compute a local fingerprint and decorate the .swiftmodule files
        let dependencies = try generateDependencies()
        let fingerprint = try generateFingerprint(dependencies.fingerprintScoped)
        try generateFingerprintOverrides(contextSpecificFingerprint: fingerprint.contextSpecific)
    }

    /// Uploads only a meta to the remote server - useful when the file artifact (.zip) already exists on a remote
    /// server and only a meta for a current commit sha has to be uploaded
    public func performMetaUpload(meta: MainArtifactMeta, for commit: String) throws {
        // Reset plugins keys as these are unique to each
        var meta = meta
        meta.pluginsKeys = [:]
        meta = try creatorPlugins.reduce(meta) { prevMeta, plugin in
            var meta = prevMeta
            // add extra keys from the plugin. A plugin overrides previously defined keys in case of duplication
            meta.pluginsKeys = try meta.pluginsKeys.merging(plugin.extraMetaKeys(prevMeta), uniquingKeysWith: { $1 })
            return meta
        }
        let metaPath = try metaWriter.write(meta, locationDir: context.targetTempDir)
        try networkClient.uploadSynchronously(metaPath, as: .meta(commit: commit))
    }

    /// Builds an artifact package and uploads it to the remote server
    public func performBuildUpload(for commit: String) throws {
        let dependencies = try generateDependencies()
        let localFingerprint = try generateFingerprint(dependencies.fingerprintScoped)
        let assetsSourcesFingerprint = try generateFingerprint(dependencies.assetSources)
        // Filekey has to be unique for the context to not mix builds Debug/Release, iphonesimulator/iphoneos etc
        let fileKey = localFingerprint.contextSpecific
        // Replace all local paths to the generic ones (e.g. $SRCROOT)
        let remappers = [remapper] + creatorPlugins.compactMap(\.customPathsRemapper)
        let remapper = DependenciesRemapperComposite(remappers)
        let abstractFingerprintFiles = try remapper.replace(localPaths: dependencies.fingerprintScoped.map(\.path))
        let abstractAssetsSourcesFiles = try remapper.replace(localPaths: dependencies.assetSources.map(\.path))
        // TODO: use `inputs` read by dependenciesReader
        var meta = MainArtifactMeta(
            dependencies: abstractFingerprintFiles,
            fileKey: fileKey,
            rawFingerprint: localFingerprint.raw,
            generationCommit: commit,
            targetName: context.targetName,
            configuration: context.configuration,
            platform: context.platform,
            xcode: context.xcodeBuildNumber,
            inputs: [],
            pluginsKeys: [:],
            assetsSources: abstractAssetsSourcesFiles,
            assetsSourcesFingerprint: assetsSourcesFingerprint.raw
        )
        meta = try creatorPlugins.reduce(meta) { prevMeta, plugin in
            var meta = prevMeta
            // add extra keys from the plugin. A plugin overrides previously defined keys in case of duplication
            meta.pluginsKeys = try meta.pluginsKeys.merging(plugin.extraMetaKeys(prevMeta), uniquingKeysWith: { $1 })
            return meta
        }


        // If a module has been built, try to decorate it with a fingerprint override
        try generateFingerprintOverrides(contextSpecificFingerprint: localFingerprint.contextSpecific)
        // Require that dSYM is generated to include in the artifact
        _ = try dSYMOrganizer.relevantDSYMLocation()
        let mainArtifact = try artifactCreator.createArtifact(artifactKey: fileKey, meta: meta)

        // Send artifact packages with a binary (+provided by plugins) first
        // In case of a failure, don't upload meta to not mislead a consumer that the artifact is available
        let artifactsToUpload = try creatorPlugins.reduce([mainArtifact]) { prevArtifacts, plugin in
            try prevArtifacts + plugin.artifactToUpload(main: meta)
        }
        try artifactsToUpload.forEach { artifact in
            try networkClient.uploadSynchronously(artifact.package, as: .artifact(id: artifact.id))
        }

        try networkClient.uploadSynchronously(mainArtifact.meta, as: .meta(commit: commit))
    }

    public func controlNextRetrigger(executableURL: URL) throws {
        // If no rc.enabled is present, we disable the Postbuild Build Phase
        guard try modeController.isEnabled() else {
            try modeController.disable()
            return
        }
        // Instruct Xcode to retrigger that phase if executable has changed so fingerprint override(s) should be updated
        // TODO: consider retriggering a phase also when any of the input files has changed
        try modeController.enable(allowedInputFiles: [], dependencies: [executableURL])
    }

    typealias GenerateDependenciesResult = (fingerprintScoped: [URL], assetSources: [URL])
    /// Reads all relevant dependencies (e.g. Xcode-embedded dependencies are skipped)
    private func generateDependencies() throws -> GenerateDependenciesResult {
        let dependencies = try dependenciesReader.findDependencies().map(URL.init(fileURLWithPath:))
        let processedDependencies = dependencyProcessor.process(dependencies)
        let fingerprintFiles = processedDependencies.fingerprintScoped.map(fingerprintOverrideManager.getFingerprintFile)
        let assetsSourceFiles = processedDependencies.assetsSource.map(fingerprintOverrideManager.getFingerprintFile)
        return (fingerprintScoped: fingerprintFiles.map { $0.url }, assetSources: assetsSourceFiles.map { $0.url })
    }

    private func generateFingerprint(_ files: [URL]) throws -> Fingerprint {
        fingerprintAccumulator.reset()
        for file in files {
            do {
                try fingerprintAccumulator.append(file)
            } catch FingerprintAccumulatorError.missingFile(let content) {
                printWarning("File at \(content.path) was not found on disc. Calculating fingerprint without it.")
            }
        }
        return try fingerprintAccumulator.generate()
    }

    /// Generates fingerprint overrides for the current module
    private func generateFingerprintOverrides(contextSpecificFingerprint: ContextSpecificFingerprint?) throws {
        // generate fingperint override only for modules (no need for ObjC targets)
        guard let modulename = context.moduleName else {
            return
        }
        try decorateSwiftmodule(modulename, contextSpecificFingerprint)
    }

    // Add extra fingerprint override to a generated module
    private func decorateSwiftmodule(_ modulename: String, _ contextSpecificFingerprint: ContextSpecificFingerprint?) throws {
        let moduleSwiftProductURL = context.productsDir
            .appendingPathComponent(context.modulesFolderPath)
            .appendingPathComponent("\(modulename).swiftmodule")
        let objcHeaderSwiftProductURL = context.derivedSourcesDir
            .appendingPathComponent("\(modulename)-Swift.h")
        // This header is obly valid if building a frameworks
        let objcHeaderSwiftPublicPathURL = context.publicHeadersFolderPath?
            .appendingPathComponent("\(modulename)-Swift.h")
        if let fingerprint = contextSpecificFingerprint {
            try fingerprintSyncer.decorate(
                sourceDir: moduleSwiftProductURL,
                fingerprint: fingerprint
            )
            try fingerprintSyncer.decorate(
                file: objcHeaderSwiftProductURL,
                fingerprint: fingerprint
            )
            if let objcPublic = objcHeaderSwiftPublicPathURL {
                try fingerprintSyncer.decorate(
                    file: objcPublic,
                    fingerprint: fingerprint
                )
            }
        } else {
            try fingerprintSyncer.delete(sourceDir: moduleSwiftProductURL)
            try fingerprintSyncer.delete(sourceDir: objcHeaderSwiftProductURL)
            if let objcPublic = objcHeaderSwiftPublicPathURL {
                try fingerprintSyncer.delete(file: objcPublic)
            }
        }
    }
}
