@testable import XCRemoteCache
import XCTest

class UnzippedArtifactSwiftProductsOrganizerTests: XCTestCase {
    private let destination: URL = "/destination"
    private var artifactLocation: URL = "/artifact"
    private var generator: SwiftcProductsGeneratorSpy!
    private var dirAccessor: DirAccessor!
    private var syncer: FileFingerprintSyncer!
    private var organizer: UnzippedArtifactSwiftProductsOrganizer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        generator = SwiftcProductsGeneratorSpy(generatedDestination: destination)
        dirAccessor = DirAccessorFake()
        syncer = FileFingerprintSyncer(
            fingerprintOverrideExtension: "md5",
            dirAccessor: dirAccessor,
            extensions: ["swiftmodule"]
        )
        organizer = UnzippedArtifactSwiftProductsOrganizer(
            arch: "arm64",
            moduleName: "MyName",
            artifactLocation: artifactLocation,
            productsGenerator: generator,
            fingerprintSyncer: syncer
        )
    }

    func testGeneratesFromValidFiles() throws {
        let expectedSourceSwiftmodule: URL = "/artifact/swiftmodule/arm64/MyName.swiftmodule"
        let expectedSourceSwiftdoc: URL = "/artifact/swiftmodule/arm64/MyName.swiftdoc"
        let expectedSourceObjCHeader: URL = "/artifact/include/arm64/MyName/MyName-Swift.h"

        try organizer.syncProducts(fingerprint: "1")

        XCTAssertEqual(generator.generated.count, 1)
        let generated = try XCTUnwrap(generator.generated.first)
        XCTAssertEqual(generated.0[.swiftmodule], expectedSourceSwiftmodule)
        XCTAssertEqual(generated.0[.swiftdoc], expectedSourceSwiftdoc)
        XCTAssertEqual(generated.1, expectedSourceObjCHeader)
    }

    func testGeneratesSwiftSourceinfoFromValidFile() throws {
        let expectedSwiftSourceInfo: URL = "/artifact/swiftmodule/arm64/MyName.swiftsourceinfo"

        try organizer.syncProducts(fingerprint: "1")

        XCTAssertEqual(generator.generated.count, 1)
        let generated = try XCTUnwrap(generator.generated.first)
        XCTAssertEqual(generated.0[.swiftsourceinfo], expectedSwiftSourceInfo)
    }

    func testDecoratesDestinationPath() throws {
        try dirAccessor.write(toPath: "/destination/MyName.swiftmodule", contents: Data())

        try organizer.syncProducts(fingerprint: "1")

        XCTAssertEqual(try dirAccessor.contents(atPath: "/destination/MyName.swiftmodule.md5"), "1".data(using: .utf8))
    }
}
