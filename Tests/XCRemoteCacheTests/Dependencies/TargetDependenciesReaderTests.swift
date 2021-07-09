@testable import XCRemoteCache
import XCTest

class TargetDependenciesReaderTests: XCTestCase {

    private let workingURL: URL = "/test"
    private var dirAccessor: DirAccessorFake!
    private var reader: TargetDependenciesReader!

    override func setUp() {
        dirAccessor = DirAccessorFake()
        /// A Factory that builds a faked dependency reader that returns a single dependency,
        /// a basename of the input .d file and the ".swift" extension
        let swiftFakeDependencyReaderFactory: (URL) -> DependenciesReader = { url in
            let fakeDependency = url.deletingPathExtension().appendingPathExtension("swift")
            return DependenciesReaderFake(dependencies: ["": [fakeDependency.path]])
        }
        reader = TargetDependenciesReader(
            workingURL,
            fileDependeciesReaderFactory: swiftFakeDependencyReaderFactory,
            dirScanner: dirAccessor
        )
    }

    func testFindsIncrementalDependencies() throws {
        let dFile: URL = "/test/some.d"
        let oFile: URL = "/test/some.o"
        try dirAccessor.write(toPath: dFile.path, contents: Data())
        try dirAccessor.write(toPath: oFile.path, contents: Data())

        let deps = try reader.findDependencies()

        XCTAssertEqual(deps, ["/test/some.swift"])
    }

    func testSkipsFindingDependenciesWhenOFileIsNotPresent() throws {
        let dFile: URL = "/test/some.d"
        try dirAccessor.write(toPath: dFile.path, contents: Data())

        let deps = try reader.findDependencies()

        XCTAssertEqual(deps, [])
    }

    func testFindsWMODependency() throws {
        let dFile: URL = "/test/some-master.d"
        try dirAccessor.write(toPath: dFile.path, contents: Data())

        let deps = try reader.findDependencies()

        XCTAssertEqual(deps, ["/test/some-master.swift"])
    }
}
