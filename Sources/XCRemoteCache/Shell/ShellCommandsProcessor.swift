import Foundation

/// Allows to patch Command arguments
protocol ArgsRewriter {
    /// Creates new invocation arguments
    /// - Parameter args: original command invocation args
    /// - Returns: command args with
    func applyArgsRewrite(_ args: [String]) throws -> [String]
}

/// Manages shell command invocations. Has a right to modify input args
/// and process command's result in a post-action
protocol ShellCommandsProcessor: ArgsRewriter {
    /// Called when the shell command finished with a success
    /// It adds a chance to read or modify output
    func postCommandProcessing() throws
}
