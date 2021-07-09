import Foundation

/// Xcode version
public struct XcodeVersion {
    /// Human readable version of the Xcode
    let version: String
    /// Build identifier, unique for each xcode build (GM, Beta etc.)
    let buildVersion: String
}

enum XcodeProbeError: Error {
    case parsingFailed(attribute: String)
}

/// Recognizes which xcode version is currently in use
protocol XcodeProbe {
    func read() throws -> XcodeVersion
}

/// Reads Xcode version used by `xcodebuild`. Calls xcodebuild command and parses output version
class XcodeProbeImpl: XcodeProbe {
    private let shell: ShellOutFunction

    init(shell: @escaping ShellOutFunction) {
        self.shell = shell
    }

    func read() throws -> XcodeVersion {
        let versionOutput = try xcodebuild("-version")
        let version = try read(attribute: "Xcode", from: versionOutput)
        let buildVersion = try read(attribute: "Build version", from: versionOutput)
        return XcodeVersion(version: version, buildVersion: buildVersion)
    }

    private func read(attribute: String, from string: String) throws -> String {
        let regex = "^\(attribute)\\s(.*)$"
        guard let caputre = string.firstCapture(regex: regex) else {
            throw XcodeProbeError.parsingFailed(attribute: attribute)
        }
        return caputre
    }

    private func xcodebuild(_ args: String...) throws -> String {
        return try shell("xcodebuild", args, nil, nil)
    }
}

private extension String {
    /// Returns a String with the first match of the regular expression capture
    /// - parameter pattern: A valid Regexp pattern
    /// - returns: A `String` with the first match of the pattern if there is at least one match
    /// - Throws: XcodeProbeError.missingCapture if the capture is not found
    func firstCapture(regex pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: count))
            guard
                let match = matches.first,
                let swiftRange = Range(match.range(at: 1), in: self)
                else {
                    return nil
            }
            return String(self[swiftRange])
        } catch {
            return nil
        }
    }
}
