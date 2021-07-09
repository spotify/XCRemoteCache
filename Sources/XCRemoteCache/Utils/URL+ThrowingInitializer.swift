import Foundation

enum URLError: Error {
    case invalidURLFormat(String)
}

public extension URL {
    /// Builds URL from a string or throws an error
    /// - Parameter string: URL building string
    /// - Throws: `URLError` if the string is invalid
    /// - Returns: URL instance
    static func build(for string: String) throws -> URL {
        if let url = URL(string: string) {
            return url
        }
        throw URLError.invalidURLFormat(string)
    }
}
