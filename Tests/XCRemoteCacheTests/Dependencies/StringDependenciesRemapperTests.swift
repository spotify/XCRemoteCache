@testable import XCRemoteCache
import XCTest

class StringDependenciesRemapperTests: XCTestCase {

    private let mappings = [StringDependenciesRemapper.Mapping(generic: "$(SRC_ROOT)", local: "/tmp/root")]
    private var remapper: StringDependenciesRemapper!

    override func setUp() {
        super.setUp()
        remapper = StringDependenciesRemapper(mappings: mappings)
    }

    func testMappingSingleGenericPathReplacesWithLocalPath() {
        let localPaths = remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift"])

        XCTAssertEqual(localPaths, ["/tmp/root/some.swift"])
    }

    func testRewritingSingleLocalPathReplacesWithGenericPath() {
        let genericPaths = remapper.replace(localPaths: ["/tmp/root/some.swift"])

        XCTAssertEqual(genericPaths, ["$(SRC_ROOT)/some.swift"])
    }

    func testRewritingLocalToGenericAndLocalIsIdentical() {
        let inputLocalPaths = ["/tmp/root/some.swift"]

        let genericPaths = remapper.replace(localPaths: inputLocalPaths)
        let localPaths = remapper.replace(genericPaths: genericPaths)

        XCTAssertEqual(localPaths, inputLocalPaths)
    }

    func testRewritingUnrelatedDirReturnsInputPath() {
        let genericPaths = remapper.replace(localPaths: ["/other/some.swift"])

        XCTAssertEqual(genericPaths, ["/other/some.swift"])
    }

    func testMultipleMatchesTakeTheFirstMapping() {
        let mappings: [StringDependenciesRemapper.Mapping] = [
            .init(generic: "$(SRC_ROOT)", local: "/tmp/root"),
            .init(generic: "$(PWD)", local: "/tmp"),
        ]
        remapper = StringDependenciesRemapper(mappings: mappings)


        let genericPaths = remapper.replace(localPaths: ["/tmp/root/some.swift", "/tmp/extra.swift"])

        XCTAssertEqual(genericPaths, ["$(SRC_ROOT)/some.swift", "$(PWD)/extra.swift"])
    }

    func testMappingsFromEnvMaps() throws {
        remapper = try StringDependenciesRemapper.buildFromEnvs(keys: ["SRC_ROOT"], envs: ["SRC_ROOT": "/tmp/root"])

        let localPaths = remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift"])

        XCTAssertEqual(localPaths, ["/tmp/root/some.swift"])
    }

    func testInvalidMappingsFromEnvFAils() throws {
        XCTAssertThrowsError(
            try StringDependenciesRemapper.buildFromEnvs(keys: ["SRC_ROOT"], envs: ["NO_SRC_ROOT": ""])
        )
    }
}
