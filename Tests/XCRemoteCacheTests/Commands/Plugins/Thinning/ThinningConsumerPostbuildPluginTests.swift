@testable import XCRemoteCache
import XCTest

class ThinningConsumerPostbuildPluginTests: XCTestCase {

    private lazy var plugin: ThinningConsumerPostbuildPlugin! =
        setupPluginWithThinnedTargets(["Target1"])
    private var dirAccessor: DirAccessor = DirAccessorFake()
    private var generator: SwiftcProductsGenerator!
    private var syncer: FingerprintSyncer!
    private var meta = MainArtifactSampleMeta.defaults
    private var organizerFactory: ThinningConsumerSwiftProductsOrganizerFactory!
    private var artifactInspector: ArtifactInspector!
    private var swiftProductsArchitecturesRecognizer: SwiftProductsArchitecturesRecognizer!
    private let swiftmoduleDestination: URL = "/products/swiftmodule.swiftmodule"
    private let swiftmoduleDocDestination: URL = "/products/swiftmodule.swiftdoc"
    private let swiftmoduleSourceInfoDestination: URL = "/products/swiftmodule.swiftsourceinfo"
    private let swiftmoduleObjCDestination: URL = "/products/header.h"

    override func setUpWithError() throws {
        try super.setUpWithError()
        syncer = FileFingerprintSyncer(
            fingerprintOverrideExtension: "md5",
            dirAccessor: dirAccessor,
            extensions: ["swiftmodule"]
        )
        generator = SwiftcProductsGeneratorFake(
            swiftmoduleDest: swiftmoduleDestination,
            swiftmoduleObjCFile: swiftmoduleObjCDestination,
            dirAccessor: dirAccessor
        )
        organizerFactory = ThinningConsumerSwiftProductsOrganizerFactoryFake(
            arch: "x86_64",
            generator: generator,
            syncer: syncer
        )
        // Indicate that Xcode generates a different architecture (x86_64-apple-ios-simulator) than currently set $ARCHS
        try dirAccessor.write(
            toPath: "/products/Aggregate.swiftmodule/x86_64-apple-ios-simulator.swiftmodule",
            contents: "0"
        )
        // Prepare valid binary in the artifact
        try dirAccessor.write(toPath: "/temp/Target1.build/active/binary.a", contents: "binary")
    }

    private func setupPluginWithThinnedTargets(_ thinnedTargets: [String]) -> ThinningConsumerPostbuildPlugin {
        ThinningConsumerPostbuildPlugin(
            targetTempDir: "/temp/Aggregate.build",
            builtProductsDir: "/products",
            productModuleName: "Aggregate",
            arch: "x86_64",
            thinnedTargets: thinnedTargets,
            artifactOrganizerFactory: ThinningConsumerArtifactOrganizerFakeFactory(),
            swiftProductOrganizerFactory: organizerFactory,
            artifactInspector: DefaultArtifactInspector(dirAccessor: dirAccessor),
            swiftProductsArchitecturesRecognizer: DefaultSwiftProductsArchitecturesRecognizer(dirAccessor: dirAccessor),
            diskCopier: DiskCopierFake(dirAccessor: dirAccessor),
            worker: WorkerFake()
        )
    }

    func testCopiesBinaryProducts() throws {
        meta.pluginsKeys = ["thinning_Target1": "1"]

        try plugin.run(meta: meta)

        XCTAssertEqual(try dirAccessor.contents(atPath: "/products/binary.a"), "binary")
    }

    func testCopiesSwiftmoduleToBuiltProducts() throws {
        meta.pluginsKeys = ["thinning_Target1": "1"]

        // Emulate the artifact contains a swiftmodule
        try dirAccessor.write(
            toPath: "/temp/Target1.build/active/swiftmodule/x86_64/Target1Module.swiftmodule",
            contents: "module"
        )
        try dirAccessor.write(
            toPath: "/temp/Target1.build/active/swiftmodule/x86_64/Target1Module.swiftdoc",
            contents: "doc"
        )
        try dirAccessor.write(
            toPath: "/temp/Target1.build/active/swiftmodule/x86_64/Target1Module.swiftsourceinfo",
            contents: "swiftsourceinfo"
        )
        try dirAccessor.write(
            toPath: "/temp/Target1.build/active/include/x86_64/Target1Module/Target1Module-Swift.h",
            contents: "header"
        )
        try dirAccessor.write(
            toPath: "/temp/Target1.build/active/swiftmodule/x86_64/Target1Module.swiftsourceinfo",
            contents: "swiftsourceinfo"
        )

        try plugin.run(meta: meta)

        XCTAssertEqual(try dirAccessor.contents(atPath: swiftmoduleDestination.path), "module")
        XCTAssertEqual(try dirAccessor.contents(atPath: swiftmoduleDocDestination.path), "doc")
        XCTAssertEqual(try dirAccessor.contents(atPath: swiftmoduleSourceInfoDestination.path), "swiftsourceinfo")
        XCTAssertEqual(try dirAccessor.contents(atPath: swiftmoduleObjCDestination.path), "header")
        XCTAssertEqual(try dirAccessor.contents(atPath: swiftmoduleSourceInfoDestination.path), "swiftsourceinfo")
    }

    func testDecoratesFingerprintOverrides() throws {
        meta.pluginsKeys = ["thinning_Target1": "1"]

        // Emulate the artifact contains a swiftmodule
        try dirAccessor.write(
            toPath: "/temp/Target1.build/active/swiftmodule/x86_64/Target1Module.swiftmodule",
            contents: "module"
        )

        try plugin.run(meta: meta)

        XCTAssertEqual(try dirAccessor.contents(atPath: "/products/swiftmodule.swiftmodule.md5"), "1")
    }

    func testRunsForAllThinnedTargetsProducts() throws {
        plugin = setupPluginWithThinnedTargets(["Target1", "Target2"])
        meta.pluginsKeys = ["thinning_Target1": "1", "thinning_Target2": "2"]
        try dirAccessor.write(toPath: "/temp/Target1.build/active/binary1.a", contents: "binary1")
        try dirAccessor.write(toPath: "/temp/Target2.build/active/binary2.a", contents: "binary2")

        try plugin.run(meta: meta)

        XCTAssertEqual(try dirAccessor.contents(atPath: "/products/binary1.a"), "binary1")
        XCTAssertEqual(try dirAccessor.contents(atPath: "/products/binary2.a"), "binary2")
    }

    func testFailsIfArtifactIsMalformed() throws {
        meta.pluginsKeys = ["thinning_Target1": "1"]

        // Emulate the artifact contains a swiftmodule
        try dirAccessor.write(toPath: "/temp/Target1.build/active/swiftmodule/x86_64/_invalidFile", contents: "module")

        XCTAssertThrowsError(try plugin.run(meta: meta)) { error in
            guard case PluginError.unrecoverableError(
                ThinningConsumerPostbuildPluginError.failed(let errors)
            ) = error else {
                XCTFail("Invalid error \(error)")
                return
            }
            XCTAssertEqual(errors.count, 1)
            guard case .some(ArtifactInspectorError.missingSwiftmoduleFileInArtifact) = errors.first else {
                XCTFail("Invalid error \(error)")
                return
            }
        }
    }

    func testFailsIfThinningArtifactIsMissing() throws {
        plugin = setupPluginWithThinnedTargets(["MissingArtifactTarget"])
        meta.pluginsKeys = ["thinning_MissingArtifactTarget": "1"]

        XCTAssertThrowsError(try plugin.run(meta: meta))
    }

    func testFailsIfThinningKeyIsMissing() throws {
        plugin = setupPluginWithThinnedTargets(["UnknownTarget"])
        meta.pluginsKeys = [:]

        XCTAssertThrowsError(try plugin.run(meta: meta)) { error in
            guard case PluginError.unrecoverableError(
                ThinningConsumerPostbuildPluginError.missingArtifactKey(["UnknownTarget"])
            ) = error else {
                XCTFail("Invalid error \(error)")
                return
            }
        }
    }
}
