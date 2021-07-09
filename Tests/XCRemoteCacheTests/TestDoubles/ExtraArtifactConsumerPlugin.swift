import Foundation
@testable import XCRemoteCache

/// Plugin that downloads an artifact with a suffix fileKey
class ExtraArtifactConsumerPrebuildPlugin: ArtifactConsumerPrebuildPlugin {

    private let suffix: String
    private let placeToDownload: URL
    private let network: RemoteNetworkClient

    init(extraArtifactSuffix suffix: String, placeToDownload location: URL, network: RemoteNetworkClient) {
        self.suffix = suffix
        placeToDownload = location
        self.network = network
    }

    func run(meta: MainArtifactMeta) throws {
        let extraArtifactId = meta.fileKey.appending(suffix)
        let artifactPlaceToDownload = placeToDownload.appendingPathComponent(extraArtifactId)

        try network.download(.artifact(id: extraArtifactId), to: artifactPlaceToDownload)
    }
}
