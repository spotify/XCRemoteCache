import Foundation
@testable import XCRemoteCache

class ArtifactConsumerPostbuildPluginSpy: ArtifactConsumerPostbuildPlugin {
    private(set) var runInvocations: [MainArtifactMeta] = []

    func run(meta: MainArtifactMeta) throws {
        runInvocations.append(meta)
    }
}
