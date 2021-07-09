import Foundation

protocol ShellOut {
    /// Calls the command and replaces current process's streams
    /// In practive returns `Never` but to allow unit testing, it returns `Void`
    /// - Parameters:
    ///   - command: process path to execute
    ///   - invocationArgs: execution arguments
    func switchToExternalProcess(command: String, invocationArgs: [String])
    /// Calls the command and waits until it finishes
    /// - Parameters:
    ///   - command: process path to execute
    ///   - invocationArgs: execution arguments
    ///   - envs: process environment variables
    func callExternalProcessAndWait(command: String, invocationArgs: [String], envs: [String: String]) throws
}

class ProcessShellOut: ShellOut {
    func switchToExternalProcess(command: String, invocationArgs: [String]) {
        let paramList = [command] + invocationArgs
        let cargs = paramList.map { strdup($0) } + [nil]
        execvp(paramList[0], cargs)

        /// C-function `execvp` returns only when the command fails
        exit(1, "execvp(\(command)) unexpectedly returned")
    }

    func callExternalProcessAndWait(command: String, invocationArgs: [String], envs: [String: String]) throws {
        try shellCall(command, args: invocationArgs, inDir: nil, environment: envs)
    }
}
