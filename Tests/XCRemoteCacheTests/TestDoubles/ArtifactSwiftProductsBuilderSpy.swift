import Foundation
@testable import XCRemoteCache

class ArtifactSwiftProductsBuilderSpy: ArtifactSwiftProductsBuilder {
    private let buildingArtifact: URL
    private let objcLocation: URL
    private(set) var addedObjCHeaders: [String: [URL]] = [:]
    private(set) var addedModuleDefinitions: [String: [URL]] = [:]

    init(buildingArtifact: URL, objcLocation: URL) {
        self.buildingArtifact = buildingArtifact
        self.objcLocation = objcLocation
    }

    func buildingArtifactLocation() -> URL {
        return buildingArtifact
    }

    func buildingArtifactObjCHeadersLocation() -> URL {
        return objcLocation
    }

    func includeObjCHeaderToTheArtifact(arch: String, headerURL: URL) throws {
        addedObjCHeaders[arch] = (addedObjCHeaders[arch] ?? []) + [headerURL]
    }

    func includeModuleDefinitionsToTheArtifact(arch: String, moduleURL: URL) throws {
        addedModuleDefinitions[arch] = (addedModuleDefinitions[arch] ?? []) + [moduleURL]
    }
}
