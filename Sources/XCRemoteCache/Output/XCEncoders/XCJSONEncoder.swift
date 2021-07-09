import Foundation

/// Creates response in a json, human friendly format
class XCJSONEncoder: XCRemoteCacheEncoder {
    private let encoder: JSONEncoder
    init() {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .prettyPrinted
        self.encoder = encoder
    }

    func encode<T>(_ value: T) throws -> String where T: Encodable {
        let data = try encoder.encode(value)
        guard let stringRepresentation = String(data: data, encoding: .utf8) else {
            throw XCRemoteCacheEncoderError.cannotRepresentOutput
        }
        return stringRepresentation
    }
}
