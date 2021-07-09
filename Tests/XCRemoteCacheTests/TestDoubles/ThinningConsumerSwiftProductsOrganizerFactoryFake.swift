@testable import XCRemoteCache
import XCTest

class ThinningConsumerSwiftProductsOrganizerFactoryFake: ThinningConsumerSwiftProductsOrganizerFactory {
    private let arch: String
    private let generator: SwiftcProductsGenerator
    private let syncer: FingerprintSyncer

    init(arch: String, generator: SwiftcProductsGenerator, syncer: FingerprintSyncer) {
        self.arch = arch
        self.generator = generator
        self.syncer = syncer
    }

    func build(architecture: String, targetName: String, moduleName: String, artifactLocation: URL) -> SwiftProductsOrganizer {
        return UnzippedArtifactSwiftProductsOrganizer(
            arch: arch,
            moduleName: moduleName,
            artifactLocation: artifactLocation,
            productsGenerator: generator,
            fingerprintSyncer: syncer
        )
    }
}
