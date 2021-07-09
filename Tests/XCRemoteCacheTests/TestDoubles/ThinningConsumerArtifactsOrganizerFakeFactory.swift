import Foundation
@testable import XCRemoteCache

class ThinningConsumerArtifactsOrganizerFakeFactory: ThinningConsumerArtifactsOrganizerFactory {
    private(set) var builtOrganizers: [ArtifactOrganizerFake] = []

    func build(targetTempDir: URL) -> ArtifactOrganizer {
        let organizer = ArtifactOrganizerFake(artifactRoot: targetTempDir)
        builtOrganizers.append(organizer)
        return organizer
    }
}
