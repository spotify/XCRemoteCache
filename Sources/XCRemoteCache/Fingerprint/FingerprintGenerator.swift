import Foundation

/// Generator of the environment-aware fingerprint
public class FingerprintGenerator: ContextAwareFingerprintAccumulator {
    private let simpleAccumulator: FingerprintAccumulator
    private let envFingerprint: RawFingerprint
    private let algorithm: HashingAlgorithm


    init(envFingerprint: RawFingerprint, _ accumulator: FingerprintAccumulator, algorithm: HashingAlgorithm) {
        self.envFingerprint = envFingerprint
        simpleAccumulator = accumulator
        self.algorithm = algorithm
    }

    public func generate() throws -> Fingerprint {
        let raw: RawFingerprint = try generate()
        let contextSpecific = generateContextSpecific(raw: raw)
        return Fingerprint(raw: raw, contextSpecific: contextSpecific)
    }

    public func append(_ content: String) throws {
        try simpleAccumulator.append(content)
    }

    public func append(_ file: URL) throws {
        try simpleAccumulator.append(file)
    }

    public func reset() {
        simpleAccumulator.reset()
    }

    public func generate() throws -> RawFingerprint {
        return try simpleAccumulator.generate()
    }

    private func generateContextSpecific(raw: String) -> String {
        algorithm.reset()
        algorithm.add(raw)
        algorithm.add(envFingerprint)
        return algorithm.finalizeString()
    }
}
