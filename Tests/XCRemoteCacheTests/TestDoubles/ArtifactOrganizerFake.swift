import Foundation
@testable import XCRemoteCache

class ArtifactOrganizerFake: ArtifactOrganizer {

    private let unzippedExtension: String
    private let artifactRoot: URL
    private var prepared: Set<String> = []
    private(set) var activated: URL?

    init(artifactRoot: URL = URL(fileURLWithPath: ""), unzippedExtension: String = "unzip") {
        self.artifactRoot = artifactRoot
        self.unzippedExtension = unzippedExtension
    }

    func prepareArtifactLocationFor(fileKey: String) throws -> ArtifactOrganizerLocationPreparationResult {
        if prepared.contains(fileKey) {
            return .artifactExists(
                artifactDir: artifactRoot.appendingPathComponent(fileKey).appendingPathExtension(unzippedExtension)
            )
        } else {
            return .preparedForArtifact(artifact: artifactRoot.appendingPathComponent(fileKey))
        }
    }

    func prepare(artifact: URL) throws -> URL {
        prepared.insert(artifact.lastPathComponent)
        return artifactRoot.appendingPathComponent(artifact.lastPathComponent).appendingPathExtension(unzippedExtension)
    }

    func getActiveArtifactLocation() -> URL {
        artifactRoot
    }

    func getActiveArtifactFilekey() throws -> RawFingerprint {
        ""
    }

    func activate(extractedArtifact: URL) throws {
        activated = extractedArtifact
    }
}
