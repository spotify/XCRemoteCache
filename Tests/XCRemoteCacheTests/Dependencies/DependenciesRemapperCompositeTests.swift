@testable import XCRemoteCache
import XCTest

class DependenciesRemapperCompositeTests: XCTestCase {

    private let mappings1 = [
        StringDependenciesRemapper.Mapping(generic: "$(SRC_ROOT)", local: "/tmp/root"),
    ]
    private let mappings2 = [
        StringDependenciesRemapper.Mapping(generic: "$(PWD)", local: "/pwd"),
    ]

    func testNoRemappersIsTransparent() {
        let remapper = DependenciesRemapperComposite([])

        let genericPath = remapper.replace(localPaths: ["/tmp/root/some.swift"])

        XCTAssertEqual(genericPath, ["/tmp/root/some.swift"])
    }

    func testOneRemapperReplacesLocalPaths() {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: mappings1),
        ])

        let genericPath = remapper.replace(localPaths: ["/tmp/root/some.swift"])

        XCTAssertEqual(genericPath, ["$(SRC_ROOT)/some.swift"])
    }

    func testOneRemapperReplacesGenericPaths() {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: mappings1),
        ])

        let localPath = remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift"])

        XCTAssertEqual(localPath, ["/tmp/root/some.swift"])
    }

    func testTwoRemappersReplacesLocalPaths() {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: mappings1),
            StringDependenciesRemapper(mappings: mappings2),
        ])

        let genericPath = remapper.replace(localPaths: ["/tmp/root/some.swift", "/pwd/other.swift"])

        XCTAssertEqual(genericPath, ["$(SRC_ROOT)/some.swift", "$(PWD)/other.swift"])
    }

    func testOneRemappersReplacesGenericPaths() {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: mappings1),
            StringDependenciesRemapper(mappings: mappings2),
        ])

        let localPath = remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift", "$(PWD)/other.swift"])

        XCTAssertEqual(localPath, ["/tmp/root/some.swift", "/pwd/other.swift"])
    }
}
