import Foundation

typealias OracleIdentifierType = String

/// Controls if the given type should be included or not
/// Example: controls if remote cache integration should be added for a given target or configuration
protocol IncludeOracle {
    /// Decides if a given type should be included or not
    /// - Parameter identifier: identifier of a type
    func shouldInclude(identifier: OracleIdentifierType) -> Bool
}

struct IncludeExcludeOracle: IncludeOracle {
    let excludes: [OracleIdentifierType]
    let includes: [OracleIdentifierType]


    func shouldInclude(identifier: OracleIdentifierType) -> Bool {
        // exclude array has precedence.
        if excludes.contains(identifier) {
            return false
        }
        guard !includes.isEmpty else {
            return true
        }
        return includes.contains(identifier)
    }
}
