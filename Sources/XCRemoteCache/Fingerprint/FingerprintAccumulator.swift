import Foundation

public typealias RawFingerprint = String
public typealias ContextSpecificFingerprint = String

public struct Fingerprint {
    /// Raw fingerprint
    let raw: RawFingerprint
    /// Raw fingerprint interleaved with the env context
    let contextSpecific: ContextSpecificFingerprint
}

enum FingerprintAccumulatorError: Error {
    case missingFile(URL)
}

/// Fingerprint generator that produces a raw String
public protocol FingerprintAccumulator {
    func reset()
    func append(_ content: String) throws
    func append(_ file: URL) throws
    func generate() throws -> RawFingerprint
}

/// Generator of the fingerprint that includes a context/environment aware fingerprint
public protocol ContextAwareFingerprintAccumulator: FingerprintAccumulator {
    func generate() throws -> Fingerprint
}
