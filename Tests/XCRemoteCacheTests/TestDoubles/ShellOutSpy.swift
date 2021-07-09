import Foundation
@testable import XCRemoteCache

class ShellOutSpy: ShellOut {
    struct Invocation: Equatable {
        let command: String
        let args: [String]
        let envs: [String: String]?
    }

    private(set) var switchedProcess: Invocation?
    private(set) var calledProcesses: [Invocation] = []

    func switchToExternalProcess(command: String, invocationArgs: [String]) {
        switchedProcess = Invocation(command: command, args: invocationArgs, envs: nil)
    }

    func callExternalProcessAndWait(command: String, invocationArgs: [String], envs: [String: String]) throws {
        calledProcesses.append(Invocation(command: command, args: invocationArgs, envs: envs))
    }
}
