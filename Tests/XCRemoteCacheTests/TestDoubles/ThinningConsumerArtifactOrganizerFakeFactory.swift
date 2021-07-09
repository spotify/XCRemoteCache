@testable import XCRemoteCache
import XCTest

class ThinningConsumerArtifactOrganizerFakeFactory: ThinningConsumerArtifactsOrganizerFactory {
    func build(targetTempDir: URL) -> ArtifactOrganizer {
        ArtifactOrganizerFake(artifactRoot: targetTempDir.appendingPathComponent("active"))
    }
}
