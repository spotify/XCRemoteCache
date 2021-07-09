import Foundation

extension URL: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self.init(fileURLWithPath: value)
    }
}
