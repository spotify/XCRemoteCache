@testable import XCRemoteCache
import XCTest

class ThinningConsumerPrebuildPluginTest: FileXCTestCase {
    private let targetName = "Aggregation"
    private var workingDir: URL!
    private var tempDir: URL!
    private var networkClient: NetworkClient!
    private var urlBuilder: URLBuilder!
    private var remoteNetworkClient: RemoteNetworkClient!
    private var factory: ThinningConsumerArtifactsOrganizerFakeFactory!
    private var worker: Worker!
    private var meta: MainArtifactMeta!
    private var artifactLocalFile: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workingDir = try prepareTempDir()
        tempDir = workingDir.appendingPathComponent("\(targetName).build")
        networkClient = NetworkClientFake(fileManager: .default)
        urlBuilder = URLBuilderFake("https://cache.com")
        remoteNetworkClient = RemoteNetworkClientImpl(networkClient, urlBuilder)
        factory = ThinningConsumerArtifactsOrganizerFakeFactory()
        meta = MainArtifactSampleMeta.defaults
        worker = WorkerFake()

        // Prepare a local file that can be uploaded to the network client fake
        artifactLocalFile = workingDir.appendingPathComponent("localFile.zip")
        try fileManager.spt_createEmptyFile(artifactLocalFile)
    }

    func testFailsIfThinnedTargetIsMissingInMeta() throws {
        let plugin = ThinningConsumerPrebuildPlugin(
            targetName: targetName,
            tempDir: tempDir,
            thinnedTargets: ["Unknown"],
            artifactsOrganizerFactory: factory,
            networkClient: remoteNetworkClient,
            worker: worker
        )

        XCTAssertThrowsError(try plugin.run(meta: meta)) { error in
            guard case PluginError.unrecoverableError(
                ThinningConsumerPrebuildPluginError.missingCachedTarget(["Unknown"])
            ) = error else {
                XCTFail("Invalid error type \(error)")
                return
            }
        }
    }

    func testDownloadsArtifactFromMeta() throws {
        try remoteNetworkClient.uploadSynchronously(artifactLocalFile, as: .artifact(id: "1"))
        let expectedActivatedArtifactPath = workingDir
            .appendingPathComponent("TargetThinned.build")
            .appendingPathComponent("1.unzip")
        meta.pluginsKeys = ["thinning_TargetThinned": "1"]
        let plugin = ThinningConsumerPrebuildPlugin(
            targetName: targetName,
            tempDir: tempDir,
            thinnedTargets: ["TargetThinned"],
            artifactsOrganizerFactory: factory,
            networkClient: remoteNetworkClient,
            worker: worker
        )


        try plugin.run(meta: meta)

        XCTAssertEqual(Set(factory.builtOrganizers.map(\.activated)), [expectedActivatedArtifactPath])
    }

    func testActivatesMultipleThinnedTargets() throws {
        try remoteNetworkClient.uploadSynchronously(artifactLocalFile, as: .artifact(id: "1"))
        try remoteNetworkClient.uploadSynchronously(artifactLocalFile, as: .artifact(id: "2"))
        meta.pluginsKeys = ["thinning_TargetThinned1": "1", "thinning_TargetThinned2": "2"]
        let expectedActivatedArtifact1Path = workingDir
            .appendingPathComponent("TargetThinned1.build")
            .appendingPathComponent("1.unzip")
        let expectedActivatedArtifact2Path = workingDir
            .appendingPathComponent("TargetThinned2.build")
            .appendingPathComponent("2.unzip")
        let plugin = ThinningConsumerPrebuildPlugin(
            targetName: targetName,
            tempDir: tempDir,
            thinnedTargets: ["TargetThinned1", "TargetThinned2"],
            artifactsOrganizerFactory: factory,
            networkClient: remoteNetworkClient,
            worker: worker
        )


        try plugin.run(meta: meta)

        let activatedArtifacts = Set(factory.builtOrganizers.map(\.activated))
        XCTAssertEqual(activatedArtifacts, [expectedActivatedArtifact1Path, expectedActivatedArtifact2Path])
    }

    func testDownloadsFailsIfSingleTargetWorkFails() throws {
        // Not uploading artifact file to the network client to trigger a failure for "TargetThinned"
        meta.pluginsKeys = ["thinning_TargetThinned": "1"]
        let plugin = ThinningConsumerPrebuildPlugin(
            targetName: targetName,
            tempDir: tempDir,
            thinnedTargets: ["TargetThinned"],
            artifactsOrganizerFactory: factory,
            networkClient: remoteNetworkClient,
            worker: worker
        )

        XCTAssertThrowsError(try plugin.run(meta: meta)) { error in
            guard case PluginError.unrecoverableError(
                ThinningConsumerPrebuildPluginError.failedPreparation
            ) = error else {
                XCTFail("Invalid error type \(error)")
                return
            }
        }
    }

    func testFailsIfTempDirIsCustomized() throws {
        let customTempDir = tempDir.appendingPathComponent("CustomSubdir")
        meta.pluginsKeys = ["thinning_TargetThinned": "1"]
        let plugin = ThinningConsumerPrebuildPlugin(
            targetName: targetName,
            tempDir: customTempDir,
            thinnedTargets: ["TargetThinned"],
            artifactsOrganizerFactory: factory,
            networkClient: remoteNetworkClient,
            worker: worker
        )

        XCTAssertThrowsError(try plugin.run(meta: meta)) { error in
            guard case PluginError.unrecoverableError(
                ThinningConsumerPrebuildPluginError.failedPreparation(let errors)
            ) = error,
                errors.count == 1,
                case ThinningConsumerPrebuildPluginError.detectedOverwrittenTempDir = errors[0]
                else {
                    XCTFail("Invalid error type \(error)")
                    return
            }
        }
    }
}
