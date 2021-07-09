import Foundation

/// Manages a file that collects all compilation invocations
protocol CompilationHistoryOrganizer {
    /// Cleans a state of clang history invocations
    func reset()
}

/// Manages a list of invocations stored in a file
class CompilationHistoryFileOrganizer: CompilationHistoryOrganizer {
    private let file: URL
    private let fileManager: FileManager

    init(_ file: URL, fileManager: FileManager) {
        self.file = file
        self.fileManager = fileManager
    }

    func reset() {
        fileManager.createFile(atPath: file.path, contents: nil, attributes: nil)
    }
}
