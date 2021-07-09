import Foundation
@testable import XCRemoteCache

class DSYMOrganizerFake: DSYMOrganizer {
    let dSYMFile: URL?
    let fileManager: FileManager

    init(dSYMFile: URL?, fileManager: FileManager = .default) {
        self.dSYMFile = dSYMFile
        self.fileManager = fileManager
    }

    func relevantDSYMLocation() throws -> URL? {
        guard let url = dSYMFile else {
            return nil
        }
        fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
        return dSYMFile
    }

    func syncDSYM(artifactPath: URL) throws {
        guard let dsym = dSYMFile else {
            return
        }
        try fileManager.spt_forceLinkItem(at: artifactPath, to: dsym)
    }

    func cleanup() throws {
        guard let dsym = dSYMFile else {
            return
        }
        try fileManager.removeItem(at: dsym)
    }
}
