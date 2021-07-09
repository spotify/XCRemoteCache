import Foundation
@testable import XCRemoteCache

class SwiftcProductsGeneratorSpy: SwiftcProductsGenerator {
    private(set) var generated: [([SwiftmoduleFileExtension: URL], URL)] = []
    private let generationDestination: URL

    init(generatedDestination: URL = "") {
        generationDestination = generatedDestination
    }

    func generateFrom(
        artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> URL {
        generated.append((
            artifactSwiftModuleFiles,
            artifactSwiftModuleObjCFile
        ))
        return generationDestination
    }
}
