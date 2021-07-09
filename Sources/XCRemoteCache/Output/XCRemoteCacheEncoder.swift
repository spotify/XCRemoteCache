enum XCRemoteCacheEncoderError: Error {
    /// Encoded data is not representable as a String
    case cannotRepresentOutput
}

/// Simplified encoder that creates String output of the response
protocol XCRemoteCacheEncoder {
    /// Encodes an instance to the String
    /// - Parameter value: value to encode
    /// - Throws: XCRemoteCacheEncoderError
    func encode<T: Encodable>(_ value: T) throws -> String
}
