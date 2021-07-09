import Yams

/// Creates response in a yaml format
class XCYAMLEncoder: XCRemoteCacheEncoder {
    private let encoder: YAMLEncoder
    init() {
        encoder = YAMLEncoder()
    }

    func encode<T>(_ value: T) throws -> String where T: Encodable {
        return try encoder.encode(value)
    }
}
