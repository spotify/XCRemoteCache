// Builds concrete `XCRemoteCacheEncoder`
class XCEncoderAbstractFactory {
    /// Builds concrete implementation `XCRemoteCacheEncoder` for specific output format
    /// - Parameter outputType: output format to
    /// - Returns: encoder to use
    func build(for format: XCOutputFormat) -> XCRemoteCacheEncoder {
        switch format {
        case .json:
            return XCJSONEncoder()
        case .yaml:
            return XCYAMLEncoder()
        }
    }
}
