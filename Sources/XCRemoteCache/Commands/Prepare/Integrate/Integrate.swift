import Foundation

/// Integrates XCRemoteCache into the existing Xcode project
protocol Integrate {
    /// Entry point for the XCRemoteCache integration
    func run() throws
}
