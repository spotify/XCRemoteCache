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

enum PrebuildResult: Equatable {
    case incompatible
    case compatible(localDependencies: [URL])
}

/// Downloads meta info for a current commit and downloads+unzips the artifact package if fingerprints match
class Prebuild {
    private let context: PrebuildContext
    private let networkClient: RemoteNetworkClient
    private let remapper: DependenciesRemapper
    private let fingerprintAccumulator: ContextAwareFingerprintAccumulator
    private let artifactsOrganizer: ArtifactOrganizer
    private let globalCacheSwitcher: GlobalCacheSwitcher
    private let metaReader: MetaReader
    private let artifactConsumerPrebuildPlugins: [ArtifactConsumerPrebuildPlugin]

    init(
        context: PrebuildContext,
        networkClient: RemoteNetworkClient,
        remapper: DependenciesRemapper,
        fingerprintAccumulator: ContextAwareFingerprintAccumulator,
        artifactsOrganizer: ArtifactOrganizer,
        globalCacheSwitcher: GlobalCacheSwitcher,
        metaReader: MetaReader,
        artifactConsumerPrebuildPlugins: [ArtifactConsumerPrebuildPlugin]
    ) {
        self.context = context
        self.networkClient = networkClient
        self.remapper = remapper
        self.fingerprintAccumulator = fingerprintAccumulator
        self.artifactsOrganizer = artifactsOrganizer
        self.globalCacheSwitcher = globalCacheSwitcher
        self.metaReader = metaReader
        self.artifactConsumerPrebuildPlugins = artifactConsumerPrebuildPlugins
    }

    // swiftlint:disable:next function_body_length
    public func perform() throws -> PrebuildResult {
        guard case .available(let commit) = context.remoteCommit else {
            return .incompatible
        }
        do {
            let metaData = try networkClient.fetch(.meta(commit: commit))
            let meta = try metaReader.read(data: metaData)
            let localDependencies = remapper.replace(genericPaths: meta.dependencies).map(URL.init(fileURLWithPath:))
            let localFingerprint = try generateFingerprint(for: localDependencies)
            if localFingerprint.raw != meta.rawFingerprint {
                if context.forceCached {
                    printWarning("""
                        The generated target product is out-of-sync, target sources don't match the XCRemoteCache
                        generated artifacts that will be used in runtime. Make sure you didn't introduce
                        any modification of the target or its dependency,
                        otherwise the generated application may be corrupted.
                    """)
                } else {
                    infoLog("""
                        Local fingerprint \(localFingerprint) does not match with remote one \(meta.rawFingerprint).
                    """)
                    return .incompatible
                }
            }

            let artifactPreparationResult = try artifactsOrganizer.prepareArtifactLocationFor(fileKey: meta.fileKey)
            switch artifactPreparationResult {
            case .artifactExists(let artifactDir):
                infoLog("Artifact exists locally at \(artifactDir)")
                try artifactsOrganizer.activate(extractedArtifact: artifactDir)
            case .preparedForArtifact(let artifactPackage):
                infoLog("Downloading artifact to \(artifactPackage)")
                try networkClient.download(.artifact(id: meta.fileKey), to: artifactPackage)

                let unzippedURL = try artifactsOrganizer.prepare(artifact: artifactPackage)
                try artifactsOrganizer.activate(extractedArtifact: unzippedURL)
                infoLog("Artifact unzipped to \(unzippedURL)")
            }

            try artifactConsumerPrebuildPlugins.forEach { plugin in
                try plugin.run(meta: meta)
            }
            return .compatible(localDependencies: localDependencies)
        } catch PluginError.unrecoverableError(let error) {
            exit(1, "\(error)")
        } catch NetworkClientError.timeout {
            if context.turnOffRemoteCacheOnFirstTimeout {
                infoLog("Network timeout observed. Falling back to local builds for all targets.")
                try globalCacheSwitcher.disable()
            }
            throw NetworkClientError.timeout
        }
    }

    public func generateFingerprint(for files: [URL]) throws -> Fingerprint {
        try files.forEach(fingerprintAccumulator.append)
        return try fingerprintAccumulator.generate()
    }
}
