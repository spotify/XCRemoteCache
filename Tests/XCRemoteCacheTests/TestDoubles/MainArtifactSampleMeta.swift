import Foundation
@testable import XCRemoteCache

enum MainArtifactSampleMeta {
    static let defaults = MainArtifactMeta(
        dependencies: [],
        fileKey: "fileKey",
        rawFingerprint: "",
        generationCommit: "",
        targetName: "",
        configuration: "",
        platform: "",
        xcode: "",
        inputs: [],
        pluginsKeys: [:]
    )
}
