import Darwin
import Foundation
import os.log


public func exit(_ exitCode: Int32, _ message: String) -> Never {
    os_log("%{public}@", log: OSLog.default, type: .error, message)
    printError(errorMessage: message)
    exit(exitCode)
}

func defaultLog(_ message: String) {
    os_log("%{public}@", log: OSLog.default, type: .default, message)
}

func errorLog(_ message: String) {
    os_log("%{public}@", log: OSLog.default, type: .error, message)
}

func infoLog(_ message: String) {
    os_log("%{public}@", log: OSLog.default, type: .info, message)
}

func debugLog(_ message: String) {
    os_log("%{public}@", log: OSLog.default, type: .debug, message)
}

func printError(errorMessage: String) {
    fputs("error: \(errorMessage)\n", stderr)
}

func printWarning(_ message: String) {
    print("warning: \(message)")
}

/// Prints a message to the user. It shows in Xcode (if applies) or console output
/// - Parameter message: message to print
func printToUser(_ message: String) {
    print("[RC] \(message)")
}
