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

// swiftlint:disable:next type_body_length
class PostbuildTests: FileXCTestCase {
    private var postbuildContext = PostbuildContext(
        mode: .producer,
        targetName: "",
        targetTempDir: "",
        compilationTempDir: "",
        configuration: "",
        platform: "",
        productsDir: "",
        moduleName: nil,
        modulesFolderPath: "",
        executablePath: "",
        srcRoot: "",
        xcodeDir: "",
        xcodeBuildNumber: "",
        remoteCommitLocation: "",
        remoteCommit: .available(commit: "123"),
        recommendedCacheAddress: "",
        cacheAddresses: [],
        statsLocation: "",
        forceCached: false,
        machOType: .staticLib,
        wasDsymGenerated: false,
        dSYMPath: "",
        arch: "",
        builtProductsDir: "",
        bundleDir: nil,
        derivedSourcesDir: "",
        thinnedTargets: [],
        action: .build,
        modeMarkerPath: "",
        overlayHeadersPath: ""
    )
    private var network = RemoteNetworkClientImpl(
        NetworkClientFake(fileManager: .default),
        URLBuilderFake(URL(fileURLWithPath: ""))
    )
    private var remapper = DependenciesRemapperFake(baseURL: URL(fileURLWithPath: ""))
    private var fingerprintGenerator = FingerprintGenerator(
        envFingerprint: "",
        FingerprintAccumulatorFake(),
        algorithm: MD5Algorithm()
    )
    private var organizer: ArtifactOrganizer!
    private var artifactCreator: DiskArtifactCreator!
    private var syncer = FileFingerprintSyncer(
        fingerprintOverrideExtension: "md5",
        dirAccessor: FileManager.default,
        extensions: ["swiftmodule"]
    )
    private var dependenciesReader = DependenciesReaderFake(dependencies: [:])
    private var processor = DependencyProcessorImpl(
        xcode: "/Xcode",
        product: "/Product",
        source: "/Source",
        intermediate: "/Intermediate",
        bundle: nil
    )
    private var overrideManager = FingerprintOverrideManagerImpl(
        overridingFileExtensions: ["swiftmodule"],
        fingerprintOverrideExtension: "md5",
        fileManager: .default
    )
    private var modeController = CacheModeControllerFake()
    private var metaReader = JsonMetaReader(fileAccessor: FileManager.default)
    private var metaWriter = JsonMetaWriter(fileWriter: FileManager.default, pretty: false)
    private static let SampleMeta = MainArtifactSampleMeta.defaults
    private var sampleMetaFile: URL!

    private func dump(_ meta: MainArtifactMeta, to metaFile: URL) throws {
        let metaData = try JSONEncoder().encode(meta)
        try fileManager.spt_writeToFile(atPath: metaFile.path, contents: metaData)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = try prepareTempDir()
        artifactCreator = DiskArtifactCreator(workingDir: tempDir, buildingArtifact: "", objcLocation: "")
        let artifactDir = tempDir.appendingPathComponent("123")
        sampleMetaFile = artifactDir.appendingPathComponent("123.json")
        try dump(Self.SampleMeta, to: sampleMetaFile)
        organizer = ArtifactOrganizerFake(artifactRoot: artifactDir)
    }

    func testDependencyFileIsConsideredInFingerprintGeneration() throws {
        dependenciesReader = DependenciesReaderFake(dependencies: ["deps": ["file.c"]])
        let accumulator = FingerprintAccumulatorFake()
        fingerprintGenerator = FingerprintGenerator(envFingerprint: "", accumulator, algorithm: MD5Algorithm())
        let startingAccumulatorState = try accumulator.generate()

        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )

        _ = try postbuild.generateFingerprintOverrides()

        XCTAssertNotEqual(try accumulator.generate(), startingAccumulatorState)
    }

    func testDependencyFileWithMissingFileIsNotConsideredInFingerprintGeneration() throws {
        dependenciesReader = DependenciesReaderFake(dependencies: ["deps": ["file.c"]])
        let accumulator = FingerprintAccumulatorImpl(algorithm: MD5Algorithm(), fileManager: FileManagerFake())
        fingerprintGenerator = FingerprintGenerator(envFingerprint: "", accumulator, algorithm: MD5Algorithm())
        let startingAccumulatorState = try accumulator.generate()

        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )

        _ = try postbuild.generateFingerprintOverrides()

        XCTAssertEqual(try accumulator.generate(), startingAccumulatorState)
    }

    func testSyncsdSYMsOnBuildCompletion() throws {
        let dir = try prepareTempDir()
        let dSYMInDerivedData = dir.appendingPathComponent("dsym")
        let dsymOrganizer = DSYMOrganizerFake(dSYMFile: dSYMInDerivedData)
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: dsymOrganizer,
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )

        try postbuild.performBuildCompletion()

        XCTAssertTrue(fileManager.fileExists(atPath: dSYMInDerivedData.path))
    }

    func testBuildUploadCreatesDsym() throws {
        let dir = try prepareTempDir()
        let dSYMInDerivedData = dir.appendingPathComponent("dsym")
        let dsymOrganizer = DSYMOrganizerFake(dSYMFile: dSYMInDerivedData)
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: dsymOrganizer,
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )

        try postbuild.performBuildUpload(for: "1")

        XCTAssertTrue(fileManager.fileExists(atPath: dSYMInDerivedData.path))
    }

    func testDecoratesSwiftModuleWithEmptyModulesFolderPath() throws {
        let dir = try prepareTempDir()
        let productsDir = dir.appendingPathComponent("Products")
        let swiftModuleDir = productsDir.appendingPathComponent("MyModule.swiftmodule")
        let swiftModuleArch = swiftModuleDir.appendingPathComponent("arm64.swiftmodule")
        let swiftModuleArchOverride = swiftModuleArch.appendingPathExtension("md5")

        try fileManager.spt_createEmptyDir(swiftModuleDir)
        try fileManager.spt_createEmptyFile(swiftModuleArch)
        let dSYMInDerivedData = dir.appendingPathComponent("dsym")
        let dsymOrganizer = DSYMOrganizerFake(dSYMFile: dSYMInDerivedData)
        postbuildContext.moduleName = "MyModule"
        postbuildContext.modulesFolderPath = ""
        postbuildContext.productsDir = productsDir
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: dsymOrganizer,
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )

        try postbuild.performBuildCompletion()

        XCTAssertTrue(fileManager.fileExists(atPath: swiftModuleArchOverride.path))
    }

    func testDecoratesSwiftModuleWithExtraModulesFolderPath() throws {
        let dir = try prepareTempDir()
        let productsDir = dir.appendingPathComponent("Products")
        let swiftModuleDir = productsDir
            .appendingPathComponent("MyModule.framework")
            .appendingPathComponent("Modules")
            .appendingPathComponent("MyModule.swiftmodule")
        let swiftModuleArch = swiftModuleDir.appendingPathComponent("arm64.swiftmodule")
        let swiftModuleArchOverride = swiftModuleArch.appendingPathExtension("md5")

        try fileManager.spt_createEmptyDir(swiftModuleDir)
        try fileManager.spt_createEmptyFile(swiftModuleArch)
        let dSYMInDerivedData = dir.appendingPathComponent("dsym")
        let dsymOrganizer = DSYMOrganizerFake(dSYMFile: dSYMInDerivedData)
        postbuildContext.moduleName = "MyModule"
        postbuildContext.modulesFolderPath = "MyModule.framework/Modules"
        postbuildContext.productsDir = productsDir
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: dsymOrganizer,
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )

        try postbuild.performBuildCompletion()

        XCTAssertTrue(fileManager.fileExists(atPath: swiftModuleArchOverride.path))
    }

    func testControlNextRetrigger() throws {
        let fakeModeController = CacheModeControllerFake()
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: fakeModeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )
        let executableURL = URL(fileURLWithPath: "file://filename")

        // given
        fakeModeController.enabled = false
        fakeModeController.disabled = false

        // when
        try postbuild.controlNextRetrigger(executableURL: executableURL)

        // then
        // Phase should be disabled and file is removed
        XCTAssert(fakeModeController.disabled)
        XCTAssert(fakeModeController.dependencies.isEmpty)

        // given
        fakeModeController.enabled = true
        fakeModeController.disabled = false

        // when
        try postbuild.controlNextRetrigger(executableURL: executableURL)

        // then
        // Phase should not be disabled and the dependencies contain the file
        XCTAssertFalse(fakeModeController.disabled)
        XCTAssertEqual([executableURL], fakeModeController.dependencies)
    }

    func testAppendsPluginKeysToMeta() throws {
        let keyToAppend = "Test"
        let plugin = MetaAppenderArtifactCreatorPlugin([keyToAppend: "Value"])
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [plugin],
            consumerPlugins: []
        )

        try postbuild.performBuildUpload(for: "1")

        let readData = try network.fetch(.meta(commit: "1"))
        let readMeta = try JSONDecoder().decode(MainArtifactMeta.self, from: readData)
        XCTAssertEqual(readMeta.pluginsKeys[keyToAppend], "Value")
    }

    func testUploadsPluginArtifact() throws {
        let dir = try prepareTempDir()
        let packageFile = dir.appendingPathComponent("package")
        try fileManager.spt_writeToFile(atPath: packageFile.path, contents: Data([1]))
        let metaFile = dir.appendingPathComponent("meta")
        let plugin = ExtraArtifactCreatorPlugin(id: "artifact-Extra", package: packageFile, meta: metaFile)
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [plugin],
            consumerPlugins: []
        )

        try postbuild.performBuildUpload(for: "1")

        let readData = try network.fetch(.artifact(id: "artifact-Extra"))
        XCTAssertEqual(readData, Data([1]))
    }

    func testCallsConsumerPlugins() throws {
        var context = postbuildContext
        context.mode = .consumer
        context.remoteCommit = .available(commit: "123")
        try network.uploadSynchronously(sampleMetaFile, as: .meta(commit: "123"))

        let consumerPlugin = ArtifactConsumerPostbuildPluginSpy()

        let postbuild = Postbuild(
            context: context,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: [consumerPlugin]
        )

        try postbuild.performBuildCompletion()

        XCTAssertEqual(consumerPlugin.runInvocations, [Self.SampleMeta])
    }

    func testCallsConsumerPluginsWithMetaOfGenerationCommit() throws {
        // 1. Upload "new" meta to the network cache
        var meta = Self.SampleMeta
        meta.generationCommit = "999"
        let metaFile = try prepareTempDir().appendingPathComponent("999.json")
        try dump(meta, to: metaFile)
        try network.uploadSynchronously(metaFile, as: .meta(commit: "999"))
        // 2. Specify which remote commit artifacts are reused
        var context = postbuildContext
        context.mode = .consumer
        context.remoteCommit = .available(commit: "999")

        let consumerPlugin = ArtifactConsumerPostbuildPluginSpy()

        let postbuild = Postbuild(
            context: context,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: [consumerPlugin]
        )

        try postbuild.performBuildCompletion()

        // Expect the meta for the remote commit, not the one in artifact root dir
        XCTAssertEqual(consumerPlugin.runInvocations, [meta])
    }

    func testFailsIfRemoteCacheIsDisabled() throws {
        var context = postbuildContext
        context.mode = .consumer
        context.remoteCommit = .unavailable

        let consumerPlugin = ArtifactConsumerPostbuildPluginSpy()

        let postbuild = Postbuild(
            context: context,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: [consumerPlugin]
        )

        XCTAssertThrowsError(try postbuild.performBuildCompletion()) { error in
            guard case PostbuildError.disabledCache = error else {
                XCTFail("Unexpected error type \(error).")
                return
            }
        }
    }

    func testGenerationFingerprintOverridesCreatesFileWithFingerprintOverride() throws {
        let productsDir = try prepareTempDir().appendingPathComponent("Products")
        let swiftmoduleFile = productsDir
            .appendingPathComponent("MyModule.swiftmodule")
            .appendingPathComponent("x86_64.swiftmodule")
        postbuildContext.moduleName = "MyModule"
        postbuildContext.productsDir = productsDir
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )
        let expectedOverride = swiftmoduleFile.appendingPathExtension("md5")
        try fileManager.spt_createEmptyFile(swiftmoduleFile)

        try postbuild.generateFingerprintOverrides()

        XCTAssertTrue(fileManager.fileExists(atPath: expectedOverride.path))
    }

    func testDeletionFingerprintDeletesPreviousFingerprint() throws {
        let productsDir = try prepareTempDir().appendingPathComponent("Products")
        let previousFingerprintOverride = productsDir
            .appendingPathComponent("MyModule.swiftmodule")
            .appendingPathComponent("x86_64.swiftmodule.md5")
        postbuildContext.moduleName = "MyModule"
        postbuildContext.productsDir = productsDir
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )
        try fileManager.spt_createEmptyFile(previousFingerprintOverride)

        try postbuild.deleteFingerprintOverrides()

        XCTAssertFalse(fileManager.fileExists(atPath: previousFingerprintOverride.path))
    }

    func testUploadingMeta() throws {
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [],
            consumerPlugins: []
        )

        try postbuild.performMetaUpload(meta: Self.SampleMeta, for: "33")


        let data = try network.fetch(.meta(commit: "33"))
        let downloadedMeta = try metaReader.read(data: data)

        XCTAssertEqual(downloadedMeta, Self.SampleMeta)
    }

    func testUploadingMetaWithNewPluginKeys() throws {
        let plugin = MetaAppenderArtifactCreatorPlugin(["New": "Value"])
        let postbuild = Postbuild(
            context: postbuildContext,
            networkClient: network,
            remapper: remapper,
            fingerprintAccumulator: fingerprintGenerator,
            artifactsOrganizer: organizer,
            artifactCreator: artifactCreator,
            fingerprintSyncer: syncer,
            dependenciesReader: dependenciesReader,
            dependencyProcessor: processor,
            fingerprintOverrideManager: overrideManager,
            dSYMOrganizer: DSYMOrganizerFake(dSYMFile: nil),
            modeController: modeController,
            metaReader: metaReader,
            metaWriter: metaWriter,
            creatorPlugins: [plugin],
            consumerPlugins: []
        )
        var meta = Self.SampleMeta
        meta.pluginsKeys = ["Previous": "Value"]
        var expectedMeta = meta
        expectedMeta.pluginsKeys = ["New": "Value"]

        try postbuild.performMetaUpload(meta: meta, for: "33")

        let data = try network.fetch(.meta(commit: "33"))
        let downloadedMeta = try metaReader.read(data: data)

        XCTAssertEqual(downloadedMeta, expectedMeta)
    }
}
// swiftlint:disable:next file_length
