import Foundation
@testable import XCRemoteCache

/// Fake that stores all invocations in memory
class InMemoryInvocationStorage: InvocationStorage {
    private let command: String
    private var invocations: [[String]]? = []

    init(command: String) {
        self.command = command
    }

    func store(args: [String]) throws {
        guard invocations != nil else {
            throw "Storage destroyed"
        }
        invocations?.append([command] + args)
    }

    func retrieveAll() throws -> [[String]] {
        defer {
            invocations = nil
        }
        return try invocations.unwrap()
    }
}

/// Storage that incorrectly returnes invocations (a list of empty commands)
class CorruptedInMemoryInvocationStorage: InvocationStorage {
    private let command: String
    private var invocations: [[String]]? = []

    init(command: String) {
        self.command = command
    }

    func store(args: [String]) throws {
        guard invocations != nil else {
            throw "Storage destroyed"
        }
        invocations?.append([command] + args)
    }

    func retrieveAll() throws -> [[String]] {
        defer {
            invocations = nil
        }
        return try invocations.unwrap().map { _ in [] }
    }
}
