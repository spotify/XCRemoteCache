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

/// Checks current mode from a configuration and based on that:
/// * triggers build completion
/// * triggers uploading artifacts to the server for a 'producer' mode
public class XCPostbuild {
    public init() {}

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func main() {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: PostbuildContext
        let statsLogger: StatsLogger
        do {
            config = try XCRemoteCacheConfigReader(env: env, fileManager: fileManager).readConfiguration()
            context = try PostbuildContext(config, env: env)
            let counterFactory: FileStatsCoordinator.CountersFactory = { file, count in
                ExclusiveFileCounter(ExclusiveFile(file, mode: .override), countersCount: count)
            }
            statsLogger = try FileStatsLogger(
                statsLocation: context.statsLocation,
                counterFactory: counterFactory,
                fileManager: fileManager
            )
        } catch {
            exit(1, "FATAL: Postbuild initialization failed with error: \(error)")
        }

        guard context.action != .index else {
            printToUser("Indexbuild. Skip remote cache")
            exit(0)
        }

        // Postbuild cannot disable marker, so NoopMarkerWriter used instead of a real file writer
        let modeController = PhaseCacheModeController(
            tempDir: context.targetTempDir,
            mergeCommitFile: context.remoteCommitLocation,
            phaseDependencyPath: config.postbuildDiscoveryPath,
            markerPath: config.modeMarkerPath,
            forceCached: context.forceCached,
            dependenciesWriter: FileDependenciesWriter.init,
            dependenciesReader: FileDependenciesReader.init,
            markerWriter: NoopMarkerWriter.init,
            fileManager: fileManager
        )


        do {
            // Initialize dependencies
            let primaryGitBranch = GitBranch(repoLocation: config.primaryRepo, branch: config.primaryBranch)
            let gitClient = GitClientImpl(repoRoot: config.repoRoot, primary: primaryGitBranch, shell: shellGetStdout)
            let pathRemapper = try StringDependenciesRemapper.buildFromEnvs(
                keys: DependenciesMapping.rewrittenEnvs,
                envs: env
            )
            let envFingerprint = try EnvironmentFingerprintGenerator(
                configuration: config,
                env: env,
                generator: FingerprintAccumulatorImpl(algorithm: MD5Algorithm(), fileManager: fileManager)
            ).generateFingerprint()
            let fingerprintFilesGenerator = FingerprintAccumulatorImpl(
                algorithm: MD5Algorithm(),
                fileManager: fileManager
            )
            let fingerprintGenerator = FingerprintGenerator(
                envFingerprint: envFingerprint,
                fingerprintFilesGenerator,
                algorithm: MD5Algorithm()
            )
            let organizer = ZipArtifactOrganizer(targetTempDir: context.targetTempDir, fileManager: fileManager)
            let artifactCreator = BuildArtifactCreator(
                buildDir: context.productsDir,
                tempDir: context.targetTempDir,
                executablePath: context.executablePath,
                moduleName: context.moduleName,
                modulesFolderPath: context.modulesFolderPath,
                dSYMPath: context.dSYMPath,
                fileManager: fileManager
            )
            let dirAccessor = DirAccessorComposer(
                fileAccessor: LazyFileAccessor(fileAccessor: fileManager),
                dirScanner: fileManager
            )
            let fingerprintSyncer = FileFingerprintSyncer(
                fingerprintOverrideExtension: config.fingerprintOverrideExtension,
                dirAccessor: dirAccessor,
                extensions: config.productFilesExtensionsWithContentOverride
            )
            let sessionFactory = DefaultURLSessionFactory(config: config)
            var awsV4Signature: AWSV4Signature?
            if !config.AWSAccessKey.isEmpty {
                awsV4Signature = AWSV4Signature(
                    secretKey: config.AWSSecretKey,
                    accessKey: config.AWSAccessKey,
                    region: config.AWSRegion,
                    service: config.AWSService,
                    date: Date(timeIntervalSinceNow: 0)
                )
            }
            let networkClient = NetworkClientImpl(
                session: sessionFactory.build(),
                retries: config.uploadRetries,
                fileManager: fileManager,
                awsV4Signature: awsV4Signature
            )
            let remoteNetworkClient = try RemoteNetworkClientAbstractFactory(
                mode: context.mode,
                downloadStreamURL: context.recommendedCacheAddress,
                upstreamStreamURL: context.cacheAddresses,
                networkClient: networkClient,
                urlBuilderFactory: {
                    try URLBuilderImpl(
                        address: $0,
                        env: env,
                        envFingerprint: envFingerprint,
                        schemaVersion: config.schemaVersion
                    )
                }
            ).build()
            let fileReaderFactory: (URL) -> DependenciesReader = {
                FileDependenciesReader($0, accessor: fileManager)
            }
            let dependenciesReader = TargetDependenciesReader(
                context.compilationTempDir,
                fileDependeciesReaderFactory: fileReaderFactory,
                dirScanner: fileManager
            )
            let dependencyProcessor = DependencyProcessorImpl(
                xcode: context.xcodeDir,
                product: context.productsDir,
                source: context.srcRoot,
                intermediate: context.targetTempDir,
                bundle: context.bundleDir
            )
            // Override fingerprints for all produced '.swiftmodule' files
            let fingerprintOverrideManager = FingerprintOverrideManagerImpl(
                overridingFileExtensions: config.productFilesExtensionsWithContentOverride,
                fingerprintOverrideExtension: config.fingerprintOverrideExtension,
                fileManager: fileManager
            )

            let binaryURL = context.productsDir.appendingPathComponent(context.executablePath)
            let dSYMOrganizer = DynamicDSYMOrganizer(
                productURL: binaryURL,
                machOType: context.machOType,
                dSYMPath: context.dSYMPath,
                wasDsymGenerated: context.wasDsymGenerated,
                fileManager: fileManager,
                shellCall: shellCall
            )
            let metaReader = JsonMetaReader(fileAccessor: fileManager)

            var creatorPlugins: [ArtifactCreatorPlugin] = []
            var consumerPlugins: [ArtifactConsumerPostbuildPlugin] = []
            if config.thinningEnabled {
                // Engage all thinning plugins
                if context.moduleName == config.thinningTargetModuleName {
                    switch context.mode {
                    case .consumer:
                        let artifactOrganizerFactory = ThinningConsumerZipArtifactsOrganizerFactory(
                            fileManager: fileManager
                        )
                        let swiftProductsLocationProvider =
                            DefaultSwiftProductsLocationProvider(
                                builtProductsDir: context.builtProductsDir,
                                derivedSourcesDir: context.derivedSourcesDir
                            )
                        let swiftOrganizerFactory = ThinningConsumerUnzippedArtifactSwiftProductsOrganizerFactory(
                            arch: context.arch,
                            productsLocationProvider: swiftProductsLocationProvider,
                            fingerprintSyncer: fingerprintSyncer,
                            diskCopier: CopyDiskCopier(fileManager: fileManager)
                        )
                        let swiftProductsArchitecturesRecognizer = DefaultSwiftProductsArchitecturesRecognizer(
                            dirAccessor: fileManager
                        )
                        let thinningPlugin = ThinningConsumerPostbuildPlugin(
                            targetTempDir: context.targetTempDir,
                            builtProductsDir: context.builtProductsDir,
                            productModuleName: config.thinningTargetModuleName,
                            arch: context.arch,
                            thinnedTargets: context.thinnedTargets,
                            artifactOrganizerFactory: artifactOrganizerFactory,
                            swiftProductOrganizerFactory: swiftOrganizerFactory,
                            artifactInspector: DefaultArtifactInspector(dirAccessor: fileManager),
                            swiftProductsArchitecturesRecognizer: swiftProductsArchitecturesRecognizer,
                            diskCopier: HardLinkDiskCopier(fileManager: fileManager),
                            worker: DispatchGroupParallelizationWorker(qos: .userInitiated)
                        )
                        consumerPlugins.append(thinningPlugin)
                    case .producer:
                        let thinningPlugin = ThinningCreatorPlugin(
                            targetTempDir: context.targetTempDir,
                            dirScanner: fileManager
                        )
                        creatorPlugins.append(thinningPlugin)
                    }
                }
            }

            let postbuildAction = Postbuild(
                context: context,
                networkClient: remoteNetworkClient,
                remapper: pathRemapper,
                fingerprintAccumulator: fingerprintGenerator,
                artifactsOrganizer: organizer,
                artifactCreator: artifactCreator,
                fingerprintSyncer: fingerprintSyncer,
                dependenciesReader: dependenciesReader,
                dependencyProcessor: dependencyProcessor,
                fingerprintOverrideManager: fingerprintOverrideManager,
                dSYMOrganizer: dSYMOrganizer,
                modeController: modeController,
                metaReader: metaReader,
                creatorPlugins: creatorPlugins,
                consumerPlugins: consumerPlugins
            )

            // Trigger build completion
            if try modeController.isEnabled() {
                // Decorate .swiftmodule in the product dir with fingerprint(s) overrides from a cache artifact
                try postbuildAction.performBuildCompletion()
            } else if context.mode == .consumer {
                // Delete previously set overrides - they are no longer valid. The compilation was
                // done locally, most likely due to some local change
                try postbuildAction.deleteFingerprintOverrides()
            }

            // Trigger uploading the artifact
            if context.mode == .producer {
                // Generate artifacts and upload to the remote server for a reference sha
                let referenceCommit = try config.publishingSha ?? gitClient.getCurrentSha()
                try postbuildAction.performBuildUpload(for: referenceCommit)
            }

            let executableURL = context.productsDir.appendingPathComponent(context.executablePath)
            try postbuildAction.controlNextRetrigger(executableURL: executableURL)

            // Populate stats event for a final RC state
            // Doing it in a postmerge, as xcswiftc (and xccc) has a right to disable RC
            if try modeController.isEnabled() {
                try statsLogger.log(.targetCacheHit)
                printToUser("Cached build for \(context.targetName) target")
            } else {
                try postbuildAction.performBuildCleanup()
                try statsLogger.log(.targetCacheMiss)
                // Producer mode doesn't use cached artifacts so modeController is not enabled. If producer
                // reaches this point, there were no issues with publishing
                let actionName = context.mode == .producer ? "Published" : "Disabled"
                printToUser("\(actionName) remote cache for \(context.targetName)")
            }
        } catch PluginError.unrecoverableError(let error) {
            exit(1, "\(error)")
        } catch {
            errorLog("Postbuild step failed with error: \(error)")
            if context.mode == .producer {
                // Producer cannot gracefully fail to not mark given sha as artifact-redy
                exit(1, "Postbuild step failed \(error)")
            }
            // disable postbuild until the next merge-with-primary
            do {
                try modeController.disable()
                // TODO: consider tracking errors in stats
                try statsLogger.log(.targetCacheMiss)
                printToUser("Disabled remote cache for \(context.targetName)")
            } catch {
                exit(1, "FATAL: Postbuild finishing failed with error: \(error)")
            }
        }
    }
}
