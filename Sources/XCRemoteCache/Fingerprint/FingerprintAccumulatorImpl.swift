import Foundation

/// Generates content fingerprint from input Strings and local file contents
public class FingerprintAccumulatorImpl: FingerprintAccumulator {
    private let algorithm: HashingAlgorithm
    private let fileManager: FileManager

    init(algorithm: HashingAlgorithm, fileManager: FileManager) {
        self.algorithm = algorithm
        self.fileManager = fileManager
    }

    public func reset() {
        algorithm.reset()
    }

    public func append(_ content: String) {
        algorithm.add(content)
    }

    public func append(_ content: URL) throws {
        // TODO: consider reading file in chunks if content file is huge
        guard let data = fileManager.contents(atPath: content.path) else {
            throw FingerprintAccumulatorError.missingFile(content)
        }
        algorithm.add(data)
    }

    public func generate() throws -> RawFingerprint {
        return algorithm.finalizeString()
    }
}
