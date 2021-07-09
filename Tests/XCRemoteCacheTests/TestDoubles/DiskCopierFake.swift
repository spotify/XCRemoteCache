@testable import XCRemoteCache
import XCTest

class DiskCopierFake: DiskCopier {
    private let dirAccessor: DirAccessor

    init(dirAccessor: DirAccessor) {
        self.dirAccessor = dirAccessor
    }

    func copy(file source: URL, destination: URL) throws {
        try dirAccessor.write(toPath: destination.path, contents: dirAccessor.contents(atPath: source.path))
    }
}
