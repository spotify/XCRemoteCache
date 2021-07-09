import Foundation

extension Data: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = value.data(using: .utf8)!
    }
}
