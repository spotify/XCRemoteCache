import Foundation
@testable import XCRemoteCache

class DependenciesReaderFake: DependenciesReader {
    private let dependencies: [String: [String]]
    init(dependencies: [String: [String]]) {
        self.dependencies = dependencies
    }

    func findDependencies() throws -> [String] {
        return dependencies.values.flatMap { $0 }
    }

    func findInputs() throws -> [String] {
        return []
    }

    func readFilesAndDependencies() throws -> [String: [String]] {
        return dependencies
    }
}
