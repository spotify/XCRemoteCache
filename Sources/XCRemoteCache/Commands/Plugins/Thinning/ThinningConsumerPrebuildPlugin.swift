import Foundation

enum ThinningConsumerPrebuildPluginError: Error {
    /// Preparing a target(s) is not possible (potentially the artifact is not available or broken)
    case failedPreparation(underlyingErrors: [Error])
    /// TEMP_TEMP_DIR env is customised, what is not supported in a thinning mode
    case detectedOverwrittenTempDir
    /// The target that should be cached was not generated on the remote side
    case missingCachedTarget(missingTargets: [String])
}

/// Prebuild plugin that downloads all thinned targets artifacts and places them in the places it would be extracted
/// in a standard (non-thinned) prebuild step
class ThinningConsumerPrebuildPlugin: ThinningConsumerPlugin, ArtifactConsumerPrebuildPlugin {
    private let tempDir: URL
    private let targetName: String
    private let thinnedTargets: [String]
    private let artifactsOrganizerFactory: ThinningConsumerArtifactsOrganizerFactory
    private let networkClient: RemoteNetworkClient
    private let worker: Worker

    /// Default initializer
    /// - Parameters:
    ///   - targetName: Target name of the current (aggregation) target
    ///   - tempDir: $(TEMP_DIR) of the current (aggregation) target
    ///   - thinnedTargets: an array of all targets that are thinned and should be downloaded and prepared
    ///   - artifactsOrganizerFactory: a factory that provides an artifact organiser
    ///   - networkClient: network client used for downloading artifacts
    ///   - worker: a manager that schedules blocks executions (potentially in parallel)
    init(
        targetName: String,
        tempDir: URL,
        thinnedTargets: [String],
        artifactsOrganizerFactory: ThinningConsumerArtifactsOrganizerFactory,
        networkClient: RemoteNetworkClient,
        worker: Worker
    ) {
        self.targetName = targetName
        self.tempDir = tempDir
        self.thinnedTargets = thinnedTargets
        self.artifactsOrganizerFactory = artifactsOrganizerFactory
        self.networkClient = networkClient
        self.worker = worker
    }

    /// Builds a $(TARGET_TEMP_DIR) for some other target, based on a pattern that current (aggregation) target was
    /// called with
    private func buildTempDir(forProductName otherProduct: String) throws -> URL {
        guard tempDir.lastPathComponent == "\(targetName).build" else {
            throw ThinningConsumerPrebuildPluginError.detectedOverwrittenTempDir
        }
        // Replace last component, which is exclusive for a target
        return tempDir.deletingLastPathComponent().appendingPathComponent("\(otherProduct).build")
    }

    /// Downloads and prepares an artifact for some thinned target
    private func downloadAndPrepareArtifactFor(productName: String, fileKey: String) throws {
        let targetTempDir = try buildTempDir(forProductName: productName)
        let targetSpecificOrganizer = artifactsOrganizerFactory.build(targetTempDir: targetTempDir)
        let artifactPreparationResult = try targetSpecificOrganizer.prepareArtifactLocationFor(fileKey: fileKey)
        switch artifactPreparationResult {
        case .artifactExists(let artifactDir):
            infoLog("Artifact exists locally at \(artifactDir)")
        case .preparedForArtifact(let artifactPackage):
            infoLog("Downloading artifact to \(artifactPackage)")
            try networkClient.download(.artifact(id: fileKey), to: artifactPackage)

            let unzippedURL = try targetSpecificOrganizer.prepare(artifact: artifactPackage)
            try targetSpecificOrganizer.activate(extractedArtifact: unzippedURL)
        }
    }

    func run(meta: MainArtifactMeta) throws {
        onRun()
        let allArtifactFileKeys = ThinningPlugin.extractAllProductArtifacts(meta: meta)
        // Verify all thinned target's fileKeys are available in the meta
        let artifactToFetchFileKeys = allArtifactFileKeys.filter { key, _ in
            thinnedTargets.contains(key)
        }
        let missingCachedTargets = Set(thinnedTargets).subtracting(allArtifactFileKeys.keys)
        guard missingCachedTargets.isEmpty else {
            let missingTargets = Array(missingCachedTargets)
            let rawError = ThinningConsumerPrebuildPluginError.missingCachedTarget(missingTargets: missingTargets)
            // Thin project requires all artifacts to be available locally - has to fail immediately
            throw PluginError.unrecoverableError(rawError)
        }

        for (productName, fileKey) in artifactToFetchFileKeys {
            worker.appendAction {
                try self.downloadAndPrepareArtifactFor(productName: productName, fileKey: fileKey)
            }
        }
        if case .errors(let errors) = worker.waitForResult() {
            let rawError = ThinningConsumerPrebuildPluginError.failedPreparation(underlyingErrors: errors)
            // Thin project requires all artifacts to be available locally - has to fail immediately
            throw PluginError.unrecoverableError(rawError)
        }
    }
}
