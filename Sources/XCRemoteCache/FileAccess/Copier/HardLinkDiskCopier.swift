import Foundation

/// Copier that uses hard links
class HardLinkDiskCopier: DiskCopier {
    private let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    func copy(file source: URL, destination: URL) throws {
        try fileManager.spt_forceLinkItem(at: source, to: destination)
    }
}
