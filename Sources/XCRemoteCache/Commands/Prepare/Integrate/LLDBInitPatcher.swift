import Foundation

/// Saves integration specific lldb command to the .lldbinit file
protocol LLDBInitPatcher {
    func enable() throws
}

/// Does nothing for patching
class NoopLLDBInitPatcher: LLDBInitPatcher {
    func enable() throws {}
}

// Saves a custom lldb command (XCRC lldb command) in a .lldbinit file with a preamble comment
class FileLLDBInitPatcher: LLDBInitPatcher {
    /// A preamble string. A line after that string is managed by XCRemoteCache
    private static let preambleString = "#RemoteCacheCustomSourceMap"

    private let fileLocation: URL
    private let lldbCommand: String
    private let fileAccessor: FileAccessor

    /// Default initailizer
    /// - Parameters:
    ///   - file: Location of the LLDB init file
    ///   - rootURL: Root location of the LLDB target source-map
    ///   - fakeSrcRoot: Arbitrary fake root location, shared between all producers and consumers
    ///   - fileManager: fileManager
    init(
        file: URL,
        rootURL: URL,
        fakeSrcRoot: URL,
        fileAccessor: FileAccessor
    ) {
        fileLocation = file
        lldbCommand = "settings set target.source-map \(fakeSrcRoot.path) \(rootURL.path)"
        self.fileAccessor = fileAccessor
    }

    private func findIndices(in collection: [String], value: String) -> [Int] {
        collection.enumerated().reduce([]) { (result, line) -> [Int] in
            if line.element == Self.preambleString {
                return result + [line.offset]
            }
            return result
        }
    }

    // Appends XCRC lldb command to the specifies file
    // Note: Doesn't modify the file if it already contains a valid command
    func enable() throws {
        var finalLines: [String]
        let xcrcLLDBCommandArray = [Self.preambleString, lldbCommand]
        if let content = try? fileAccessor.contents(atPath: fileLocation.path) {
            let contentString = String(data: content, encoding: .utf8)!
            let originalContentLines = contentString.components(separatedBy: .newlines)
            var contentLines = originalContentLines
            let preambleIndices = findIndices(in: contentLines, value: Self.preambleString)

            if preambleIndices.count > 0 {
                let firstLLDBCommandIndex = preambleIndices[0] + 1
                if firstLLDBCommandIndex >= contentLines.count {
                    // corrupted file, append the script line at the bottom
                    contentLines.append(lldbCommand)
                } else {
                    if preambleIndices.count == 1 && contentLines[firstLLDBCommandIndex] == lldbCommand {
                        // the file content is already valid
                        return
                    }
                    contentLines[firstLLDBCommandIndex] = lldbCommand
                }

                // Delete excessive XCRC lldb commands
                for index in preambleIndices.dropFirst().reversed() {
                    let rangeEnd = min(index + 1, contentLines.count - 1)
                    contentLines.removeSubrange(index...rangeEnd)
                }
            } else {
                contentLines += xcrcLLDBCommandArray
            }
            finalLines = contentLines
        } else {
            finalLines = xcrcLLDBCommandArray
        }
        // Save to disk
        if finalLines.suffix(xcrcLLDBCommandArray.count) == xcrcLLDBCommandArray {
            // always end with empty line when appending a command at the bottom
            finalLines.append("")
        }
        let finalContent = finalLines.joined(separator: "\n").data(using: .utf8)
        try fileAccessor.write(toPath: fileLocation.path, contents: finalContent)
    }
}
