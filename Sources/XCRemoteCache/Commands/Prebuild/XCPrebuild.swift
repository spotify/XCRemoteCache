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

public class XCPrebuild {
    public init() {}

    // swiftlint:disable:next function_body_length
    public func main() {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: PrebuildContext
        do {
            config = try XCRemoteCacheConfigReader(env: env, fileReader: fileManager).readConfiguration()
            context = try PrebuildContext(config, env: env)
            updateProcessTag(context.targetName)
        } catch {
            // Fatal error:
            exit(1, "FATAL: Prebuild initialization failed with error: \(error)")
        }

        // Xcode may call xcprebuild phase even none of compilation files has changed (e.g. when switching between
        // simulator versions) and modifying 'mdate' of a marker file unnecessary invalidates compilation steps
        // that have to repeat their "use-from-cache" flow
        // To not introduce additional overhead, only marker writer file is saved in a lazy mode
        let lazyMarkerWriterFactory: (URL, FileManager) -> MarkerWriter = { url, fileManager in
            let lazyFileAccessor = LazyFileAccessor(fileAccessor: fileManager)
            return FileMarkerWriter(url, fileAccessor: lazyFileAccessor)
        }
        let globalCacheSwitcher = FileGlobalCacheSwitcher(context.remoteCommitLocation, fileAccessor: fileManager)
        let modeController = PhaseCacheModeController(
            tempDir: context.targetTempDir,
            mergeCommitFile: context.remoteCommitLocation,
            phaseDependencyPath: config.prebuildDiscoveryPath,
            markerPath: config.modeMarkerPath,
            forceCached: context.forceCached,
            dependenciesWriter: FileDependenciesWriter.init,
            dependenciesReader: FileDependenciesReader.init,
            markerWriter: lazyMarkerWriterFactory,
            llbuildLockFile: context.llbuildIdLockFile,
            fileManager: fileManager
        )

        guard config.mode != .producer else {
            // Prebuild phase for a producer is noop
            // TODO: Consider a note to not adding that prebuildstep to the Xcode target
            disableRemoteCache(
                modeController: modeController,
                errorMessage: "Prebuild step disabled, selected mode: \(config.mode)"
            )
            exit(0)
        }

        guard !modeController.shouldDisable(for: context.remoteCommit) else {
            // Previous RC runs explicitly disabled using remote cache for that remote sha
            // Short-circut early all `xc*` apps until remote commit change
            disableRemoteCache(
                modeController: modeController,
                errorMessage: "Prebuild step was disabled for current commit: \(context.remoteCommit)"
            )
            exit(0)
        }

        let compilationHistoryOrganizer = CompilationHistoryFileOrganizer(
            context.compilationHistoryFile,
            fileManager: fileManager
        )
        do {
            let envFingerprint = try EnvironmentFingerprintGenerator(
                configuration: config,
                env: env,
                generator: FingerprintAccumulatorImpl(algorithm: MD5Algorithm(), fileManager: fileManager)
            ).generateFingerprint()
            let urlBuilder = try URLBuilderImpl(
                address: context.recommendedCacheAddress,
                env: env,
                envFingerprint: envFingerprint,
                schemaVersion: config.schemaVersion
            )
            let sessionFactory = DefaultURLSessionFactory(config: config)
            var awsV4Signature: AWSV4Signature?
            if !config.AWSAccessKey.isEmpty {
                awsV4Signature = AWSV4Signature(
                    secretKey: config.AWSSecretKey,
                    accessKey: config.AWSAccessKey,
                    securityToken: config.AWSSecurityToken,
                    region: config.AWSRegion,
                    service: config.AWSService,
                    date: Date(timeIntervalSinceNow: 0)
                )
            }
            let networkClient = NetworkClientImpl(
                session: sessionFactory.build(),
                retries: config.downloadRetries,
                retryDelay: config.retryDelay,
                fileManager: fileManager,
                awsV4Signature: awsV4Signature
            )
            let cacheURL: URL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let cacheURLBuilder = LocalURLBuilderImpl(cachePath: cacheURL)
            let cacheNetworkClient = CachedNetworkClient(
                localURLBuilder: cacheURLBuilder,
                client: networkClient,
                fileManager: fileManager
            )
            let client: NetworkClient = config.disableHttpCache ? networkClient : cacheNetworkClient
            let remoteNetworkClient = RemoteNetworkClientImpl(client, urlBuilder)
            let envsRemapper = try PathDependenciesRemapperFactory().build(
                orderKeys: DependenciesMapping.rewrittenEnvs + config.customRewriteEnvs,
                envs: env,
                customMappings: config.outOfBandMappings
            )
            var remappers: [DependenciesRemapper] = []
            if !config.disableVFSOverlay {
                // As PrebuildContext assumes file location and its filename (`all-product-headers.yaml`)
                // do not fail in case of a missing headers overlay file
                let overlayReader = JsonOverlayReader(
                    context.overlayHeadersPath,
                    mode: .bestEffort,
                    fileReader: fileManager
                )
                let overlayRemapper = OverlayDependenciesRemapper(
                    overlayReader: overlayReader
                )
                remappers.append(overlayRemapper)
            }
            remappers.append(envsRemapper)
            let pathRemapper = DependenciesRemapperComposite(remappers)
            let filesFingerprintGenerator = FingerprintAccumulatorImpl(
                algorithm: MD5Algorithm(),
                fileManager: fileManager
            )
            let fingerprintGenerator = FingerprintGenerator(
                envFingerprint: envFingerprint,
                filesFingerprintGenerator,
                algorithm: MD5Algorithm()
            )
            let fileRemapper = TextFileDependenciesRemapper(
                remapper: envsRemapper,
                fileAccessor: fileManager
            )
            let artifactProcessor = UnzippedArtifactProcessor(fileRemapper: fileRemapper, dirScanner: fileManager)
            let organizer = ZipArtifactOrganizer(
                targetTempDir: context.targetTempDir,
                artifactProcessors: [artifactProcessor],
                fileManager: fileManager
            )
            let metaReader = JsonMetaReader(fileAccessor: fileManager)
            var consumerPlugins: [ArtifactConsumerPrebuildPlugin] = []

            if config.thinningEnabled {
                if context.moduleName == config.thinningTargetModuleName, let thinnedTarget = context.thinnedTargets {
                    let organizerFactory = ThinningConsumerZipArtifactsOrganizerFactory(
                        processors: [artifactProcessor],
                        fileManager: fileManager
                    )
                    let aggregationPlugin = ThinningConsumerPrebuildPlugin(
                        targetName: context.targetName,
                        tempDir: context.targetTempDir,
                        thinnedTargets: thinnedTarget,
                        artifactsOrganizerFactory: organizerFactory,
                        networkClient: remoteNetworkClient,
                        worker: DispatchGroupParallelizationWorker(qos: .userInitiated)
                    )
                    consumerPlugins.append(aggregationPlugin)
                }
            }

            let prebuildAction = Prebuild(
                context: context,
                networkClient: remoteNetworkClient,
                remapper: pathRemapper,
                fingerprintAccumulator: fingerprintGenerator,
                artifactsOrganizer: organizer,
                globalCacheSwitcher: globalCacheSwitcher,
                metaReader: metaReader,
                artifactConsumerPrebuildPlugins: consumerPlugins
            )

            let actionResult = try prebuildAction.perform()
            switch actionResult {
            case .incompatible:
                infoLog("Remote cache cannot be used")
                try modeController.disable()
            case .compatible(localDependencies: let dependencies):
                // TODO: pass `allowedInputFiles` observed in the build time
                try modeController.enable(allowedInputFiles: dependencies, dependencies: dependencies)
            case .disabled:
                infoLog("XCRemoteCache is explicitly disabled")
                try modeController.disable()
            }
        } catch {
            disableRemoteCache(
                modeController: modeController,
                errorMessage: "Prebuild step failed with error: \(error)"
            )
        }
        compilationHistoryOrganizer.reset()
    }

    private func disableRemoteCache(modeController: PhaseCacheModeController, errorMessage: String?) {
        if let message = errorMessage {
            errorLog(message)
        }
        do {
            try modeController.disable()
        } catch {
            exit(1, "FATAL: Prebuild fallback to source-mode failed with error: \(error)")
        }
    }
}
