import Foundation
@testable import XCRemoteCache

private func which(_ cmd: String) throws -> String {
    return try shellGetStdout("/usr/bin/which", args: [cmd])
}

/// Triggers a command without waiting it to finish
func startExec(_ cmd: String, args: [String] = [], inDir dir: String? = nil) throws -> Process {
    let absCmd = try cmd.starts(with: "/") ? cmd : which(cmd)

    let task = Process()

    task.launchPath = absCmd
    task.arguments = args
    task.standardError = Process().standardError
    task.standardOutput = Process().standardOutput
    if let dir = dir {
        task.currentDirectoryPath = dir
    }
    task.launch()
    return task
}

/// Waits for a process finish
func waitFor(_ task: Process) -> Int32 {
    task.waitUntilExit()
    return task.terminationStatus
}
