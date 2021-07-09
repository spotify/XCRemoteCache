import Foundation

/// Copier that physically copies files (as duplicates)
class CopyDiskCopier: DiskCopier {
    private let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    func copy(file source: URL, destination: URL) throws {
        let parent = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
        }
        try fileManager.spt_forceCopyItem(at: source, to: destination)
    }
}
