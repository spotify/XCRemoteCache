import Foundation
@testable import XCRemoteCache

/// A Fake that generates a full swift product (including required and optional swiftmodule files)
class SwiftcProductsGeneratorFake: SwiftcProductsGenerator {
    private let swiftmoduleDest: URL
    private let swiftmoduleObjCFile: URL
    private let dirAccessor: DirAccessor

    init(
        swiftmoduleDest: URL,
        swiftmoduleObjCFile: URL,
        dirAccessor: DirAccessor
    ) {
        self.swiftmoduleDest = swiftmoduleDest
        self.swiftmoduleObjCFile = swiftmoduleObjCFile
        self.dirAccessor = dirAccessor
    }

    func generateFrom(
        artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> URL {
        let swiftmoduleDestBasename = swiftmoduleDest.deletingPathExtension()
        for (ext, url) in artifactSwiftModuleFiles {
            try dirAccessor.write(
                toPath: swiftmoduleDestBasename.appendingPathExtension(ext.rawValue).path,
                contents: dirAccessor.contents(atPath: url.path)
            )
        }
        try dirAccessor.write(
            toPath: swiftmoduleObjCFile.path,
            contents: dirAccessor.contents(atPath: artifactSwiftModuleObjCFile.path)
        )
        return swiftmoduleDest.deletingLastPathComponent()
    }
}
