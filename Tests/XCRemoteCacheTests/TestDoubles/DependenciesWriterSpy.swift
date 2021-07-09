import Foundation
@testable import XCRemoteCache

class DependenciesWriterSpy: DependenciesWriter {
    private(set) var wroteSkipForSha: String?
    func write(skipForSha: String) throws {
        wroteSkipForSha = skipForSha
    }

    private(set) var wroteDependencies: [String: [String]]?
    func write(dependencies: [String: [String]]) throws {
        wroteDependencies = dependencies
    }
}
