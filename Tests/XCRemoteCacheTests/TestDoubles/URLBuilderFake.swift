import Foundation
@testable import XCRemoteCache

class URLBuilderFake: URLBuilder {
    private let address: URL
    init(_ address: URL) {
        self.address = address
    }

    func location(for remote: RemoteCacheFile) throws -> URL {
        switch remote {
        case .artifact(id: let artifactId):
            return address.appendingPathComponent("file").appendingPathComponent(artifactId)
        case .marker(commit: let commit):
            return address.appendingPathComponent("marker").appendingPathComponent(commit)
        case .meta(commit: let commit):
            return address.appendingPathComponent("meta").appendingPathComponent(commit)
        }
    }
}
