import Foundation
@testable import XCRemoteCache

class FingerprintAccumulatorFake: FingerprintAccumulator {
    private var appendedStrings: [String] = []
    func append(_ content: String) throws {
        appendedStrings.append(content)
    }

    func reset() {
        appendedStrings = []
    }

    func append(_ file: URL) throws {
        appendedStrings.append("FILE{\(file.path)}")
    }

    func generate() throws -> RawFingerprint { return appendedStrings.joined(separator: ",") }
}
