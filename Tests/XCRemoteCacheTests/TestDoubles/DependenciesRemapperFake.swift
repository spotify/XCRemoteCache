import Foundation
@testable import XCRemoteCache

class DependenciesRemapperFake: DependenciesRemapper {
    private let baseURL: URL
    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func replace(genericPaths: [String]) -> [String] {
        genericPaths.map(baseURL.appendingPathComponent).map(\.path)
    }

    func replace(localPaths: [String]) -> [String] {
        localPaths.map { u -> String in
            let p = URL(fileURLWithPath: u, relativeTo: baseURL)
            return p.relativePath
        }
    }
}
