import Foundation

/// Extends the swiftc product generation (when consuming cached artifact(s))
protocol SwiftcProductGenerationPlugin {

    /// Allows to extend the production generation
    /// - Parameter for: info of all compilation files passed to the swiftc invocation
    func generate(for: SwiftCompilationInfo) throws
}
