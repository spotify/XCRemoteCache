import Foundation

/// Factory to create `ArtifactOrganizer`
protocol ThinningConsumerArtifactsOrganizerFactory {
    /// Builds artifacts aggregator that oranizes artifacts in a dedicated target temp dir
    /// - Parameter targetTempDir: location where should the organizer organize the artifact ($TARGET_TEMP_DIR)
    func build(targetTempDir: URL) -> ArtifactOrganizer
}

class ThinningConsumerZipArtifactsOrganizerFactory: ThinningConsumerArtifactsOrganizerFactory {
    private let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    func build(targetTempDir: URL) -> ArtifactOrganizer {
        ZipArtifactOrganizer(targetTempDir: targetTempDir, fileManager: fileManager)
    }
}
