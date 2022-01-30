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
class PrebuildTests: FileXCTestCase {

    private let sampleURL = URL(fileURLWithPath: "/")
    private let artifactsRoot = URL(fileURLWithPath: "/")
    private let compilationHistory = URL(fileURLWithPath: "/history.compile")
    private let commitSha = "a"
    private var metaContent: URL!
    private var generator: FingerprintGenerator!
    private var remoteCacheURL: URL!
    private var network: NetworkClient!
    private var remoteNetwork: RemoteNetworkClientImpl!
    private var remapper: DependenciesRemapperFake!
    private var metaReader: MetaReader!
    private var contextNonCached: PrebuildContext!
    private var contextCached: PrebuildContext!
    private var organizer: ArtifactOrganizerFake!
    private var globalCacheSwitcher: InMemoryGlobalCacheSwitcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        metaContent = try generateMeta(fingerprint: "")
        generator = FingerprintGenerator(
            envFingerprint: "",
            FingerprintAccumulatorImpl(algorithm: MD5Algorithm(), fileManager: .default),
            algorithm: MD5Algorithm()
        )
        remoteCacheURL = try XCTUnwrap(URL(string: "https://example.com"))
        network = NetworkClientFake(fileManager: .default)
        remoteNetwork = RemoteNetworkClientImpl(network, URLBuilderFake(remoteCacheURL))
        remapper = DependenciesRemapperFake(baseURL: URL(fileURLWithPath: "/"))
        metaReader = JsonMetaReader(fileAccessor: FileManager.default)
        contextNonCached = PrebuildContext(
            targetTempDir: sampleURL,
            productsDir: sampleURL,
            moduleName: nil,
            remoteCommit: .available(commit: commitSha),
            remoteCommitLocation: sampleURL,
            recommendedCacheAddress: sampleURL,
            forceCached: false,
            compilationHistoryFile: compilationHistory,
            turnOffRemoteCacheOnFirstTimeout: true,
            targetName: "",
            overlayHeadersPath: ""
        )
        contextCached = PrebuildContext(
            targetTempDir: sampleURL,
            productsDir: sampleURL,
            moduleName: nil,
            remoteCommit: .available(commit: commitSha),
            remoteCommitLocation: sampleURL,
            recommendedCacheAddress: sampleURL,
            forceCached: true,
            compilationHistoryFile: compilationHistory,
            turnOffRemoteCacheOnFirstTimeout: true,
            targetName: "",
            overlayHeadersPath: ""
        )
        organizer = ArtifactOrganizerFake(artifactRoot: artifactsRoot, unzippedExtension: "unzip")
        globalCacheSwitcher = InMemoryGlobalCacheSwitcher()
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: metaContent)
        metaContent = nil
        generator = nil
        remoteCacheURL = nil
        network = nil
        remoteNetwork = nil
        remapper = nil
        contextNonCached = nil
        contextCached = nil
        organizer = nil
        try super.tearDownWithError()
    }

    private func generateMeta(fingerprint: String, filekey: String = "", function: String = #function) throws -> URL {
        let content = """
        { "dependencies": [], "fileKey": "\(filekey)", "rawFingerprint": "\(fingerprint)", "generationCommit": "",\
        "targetName": "", "configuration": "", "platform":"", "xcode":"", "inputs": [], "pluginsKeys": {}}
        """
        let directory = NSTemporaryDirectory()
        let url = try NSURL.fileURL(withPathComponents: [directory, function]).unwrap()
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testAlreadyExtractedArtifactIsActivated() throws {
        metaContent = try generateMeta(fingerprint: generator.generate(), filekey: "1")
        let downloadedArtifactPackage = artifactsRoot.appendingPathComponent("1")
        let extractedArtifact = downloadedArtifactPackage.appendingPathExtension("unzip")

        _ = try organizer.prepare(artifact: downloadedArtifactPackage)
        try network.uploadSynchronously(
            metaContent,
            as: remoteCacheURL.appendingPathComponent("meta").appendingPathComponent(commitSha)
        )

        let prebuild = Prebuild(
            context: contextNonCached,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: organizer,
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: []
        )

        _ = try prebuild.perform()

        XCTAssertEqual(organizer.activated, extractedArtifact)
    }

    func testArtifactIsActivatedAfterDownloadAndUnzip() throws {
        metaContent = try generateMeta(fingerprint: generator.generate(), filekey: "1")
        let downloadedArtifactPackage = artifactsRoot.appendingPathComponent("1")
        let extractedArtifact = downloadedArtifactPackage.appendingPathExtension("unzip")

        try network.uploadSynchronously(
            metaContent,
            as: remoteCacheURL.appendingPathComponent("meta").appendingPathComponent(commitSha)
        )
        try network.createSynchronously(remoteCacheURL.appendingPathComponent("file").appendingPathComponent("1"))

        let prebuild = Prebuild(
            context: contextNonCached,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: organizer,
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: []
        )

        _ = try prebuild.perform()

        XCTAssertEqual(organizer.activated, extractedArtifact)
    }

    func testWithFingerprintMatchUsesCached() throws {
        metaContent = try generateMeta(fingerprint: generator.generate())
        try network.uploadSynchronously(
            metaContent,
            as: remoteCacheURL.appendingPathComponent("meta").appendingPathComponent(commitSha)
        )
        try network.createSynchronously(remoteCacheURL.appendingPathComponent("file").appendingPathComponent(""))


        let prebuild = Prebuild(
            context: contextNonCached,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: ArtifactOrganizerFake(),
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: []
        )

        let result = try prebuild.perform()
        XCTAssertEqual(result, .compatible(localDependencies: []))
    }

    func testWithFingerprintMismatchUsesFallback() throws {
        try network.uploadSynchronously(
            metaContent,
            as: remoteCacheURL.appendingPathComponent("meta").appendingPathComponent(commitSha)
        )

        let prebuild = Prebuild(
            context: contextNonCached,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: ArtifactOrganizerFake(),
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: []
        )

        let result = try prebuild.perform()
        XCTAssertEqual(result, .incompatible)
    }


    func testForCachedModeMismatchedStillUseCachedArtifact() throws {
        try network.uploadSynchronously(
            metaContent,
            as: remoteCacheURL.appendingPathComponent("meta").appendingPathComponent(commitSha)
        )
        try network.createSynchronously(remoteCacheURL.appendingPathComponent("file").appendingPathComponent(""))

        let prebuild = Prebuild(
            context: contextCached,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: ArtifactOrganizerFake(),
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: []
        )

        let result = try prebuild.perform()
        XCTAssertEqual(result, .compatible(localDependencies: []))
    }

    func testReturnsIncompatibleWhenRemoteCacheCommitIsNotAvailable() throws {
        contextNonCached = PrebuildContext(
            targetTempDir: sampleURL,
            productsDir: sampleURL,
            moduleName: nil,
            remoteCommit: .unavailable,
            remoteCommitLocation: sampleURL,
            recommendedCacheAddress: sampleURL,
            forceCached: false,
            compilationHistoryFile: compilationHistory,
            turnOffRemoteCacheOnFirstTimeout: true,
            targetName: "",
            overlayHeadersPath: ""
        )

        let prebuild = Prebuild(
            context: contextNonCached,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: organizer,
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: []
        )

        XCTAssertEqual(try prebuild.perform(), .incompatible)
    }

    func testCallsPluginsPrepareArtifacts() throws {
        let workingDir = try prepareTempDir()
        let expectedDownloadedExtraArtifact = try prepareTempDir().appendingPathComponent("1-extra")
        contextNonCached = PrebuildContext(
            targetTempDir: sampleURL,
            productsDir: sampleURL,
            moduleName: nil,
            remoteCommit: .unavailable,
            remoteCommitLocation: sampleURL,
            recommendedCacheAddress: sampleURL,
            forceCached: false,
            compilationHistoryFile: compilationHistory,
            turnOffRemoteCacheOnFirstTimeout: true,
            targetName: "",
            overlayHeadersPath: ""
        )
        metaContent = try generateMeta(fingerprint: generator.generate(), filekey: "1")
        let downloadedArtifactPackage = artifactsRoot.appendingPathComponent("1")

        _ = try organizer.prepare(artifact: downloadedArtifactPackage)
        let plugin = ExtraArtifactConsumerPrebuildPlugin(
            extraArtifactSuffix: "-extra",
            placeToDownload: workingDir,
            network: remoteNetwork
        )
        let prebuild = Prebuild(
            context: contextCached,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: organizer,
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: [plugin]
        )
        try remoteNetwork.uploadSynchronously(metaContent, as: .meta(commit: commitSha))
        try remoteNetwork.uploadSynchronously(metaContent, as: .artifact(id: "1-extra"))

        _ = try prebuild.perform()

        XCTAssertTrue(fileManager.fileExists(atPath: expectedDownloadedExtraArtifact.path))
    }

    func testImportantTimeoutDisablesRCAndThrowsError() throws {
        network = TimeoutingNetworkClient()
        remoteNetwork = RemoteNetworkClientImpl(network, URLBuilderFake(remoteCacheURL))
        try globalCacheSwitcher.enable(sha: "1")
        let prebuild = Prebuild(
            context: contextCached,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: organizer,
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: []
        )

        XCTAssertThrowsError(try prebuild.perform())

        XCTAssertEqual(globalCacheSwitcher.state, .disabled)
    }

    func testNotImportantNetworkTimeoutDoesntDisableRCAndThrowsError() throws {
        network = TimeoutingNetworkClient()
        remoteNetwork = RemoteNetworkClientImpl(network, URLBuilderFake(remoteCacheURL))
        let liberalTimeoutContext = PrebuildContext(
            targetTempDir: sampleURL,
            productsDir: sampleURL,
            moduleName: nil,
            remoteCommit: .available(commit: commitSha),
            remoteCommitLocation: sampleURL,
            recommendedCacheAddress: sampleURL,
            forceCached: false,
            compilationHistoryFile: compilationHistory,
            turnOffRemoteCacheOnFirstTimeout: false,
            targetName: "",
            overlayHeadersPath: ""
        )
        try globalCacheSwitcher.enable(sha: "1")
        let prebuild = Prebuild(
            context: liberalTimeoutContext,
            networkClient: remoteNetwork,
            remapper: remapper,
            fingerprintAccumulator: generator,
            artifactsOrganizer: organizer,
            globalCacheSwitcher: globalCacheSwitcher,
            metaReader: metaReader,
            artifactConsumerPrebuildPlugins: []
        )

        XCTAssertThrowsError(try prebuild.perform())

        XCTAssertEqual(globalCacheSwitcher.state, .enabled(sha: "1"))
    }
}
