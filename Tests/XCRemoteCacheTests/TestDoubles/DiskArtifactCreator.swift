import Foundation
@testable import XCRemoteCache

/// Creator that saves artifacts on a disk within a workingDir location
class DiskArtifactCreator: ArtifactSwiftProductsBuilderSpy, ArtifactCreator {
    private let workingDir: URL
    private let fileManager: FileManager

    init(workingDir: URL, buildingArtifact: URL, objcLocation: URL) {
        self.workingDir = workingDir
        fileManager = FileManager.default
        super.init(buildingArtifact: buildingArtifact, objcLocation: objcLocation)
    }

    func createArtifact(artifactKey: String, meta: MainArtifactMeta) throws -> Artifact {
        let metaURL = workingDir.appendingPathComponent(UUID().uuidString)
        let metaData = try JSONEncoder().encode(meta)
        try fileManager.spt_writeToFile(atPath: metaURL.path, contents: metaData)
        let artifact = Artifact(id: artifactKey, package: "", meta: metaURL)
        return artifact
    }
}
