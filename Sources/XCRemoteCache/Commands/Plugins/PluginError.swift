import Foundation

/// Errors thrown from Plugins
enum PluginError: Error {
    /// The error is severe and the command should fail immediately
    case unrecoverableError(Error)
}
