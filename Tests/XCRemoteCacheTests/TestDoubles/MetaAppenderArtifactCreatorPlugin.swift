import Foundation
@testable import XCRemoteCache

/// Plugin that asks adding extra meta keys
class MetaAppenderArtifactCreatorPlugin: ArtifactCreatorPlugin {
    var customPathsRemapper: DependenciesRemapper?
    private let appendedKeys: [String: String]

    init(_ keys: [String: String]) {
        appendedKeys = keys
    }

    func extraMetaKeys(_ meta: MainArtifactMeta) -> [String: String] {
        return appendedKeys
    }

    func artifactToUpload(main: MainArtifactMeta) throws -> [Artifact] {
        []
    }
}

/// Plugin that asks to upload an extra artifact
class ExtraArtifactCreatorPlugin: ArtifactCreatorPlugin {
    var customPathsRemapper: DependenciesRemapper?
    private let id: String
    private let package: URL
    private let meta: URL

    init(id: String, package: URL, meta: URL) {
        self.id = id
        self.package = package
        self.meta = meta
    }

    func extraMetaKeys(_ meta: MainArtifactMeta) -> [String: String] {
        [:]
    }

    func artifactToUpload(main: MainArtifactMeta) throws -> [Artifact] {
        [Artifact(id: id, package: package, meta: meta)]
    }
}
