@testable import XCRemoteCache
import XCTest

class DependencyProcessorImplTests: XCTestCase {

    let processor = DependencyProcessorImpl(
        xcode: "/Xcode",
        product: "/Product",
        source: "/Source",
        intermediate: "/Intermediate",
        bundle: "/Bundle"
    )

    func testIntermediateFileIsSkippedForProductAndSourceSubdirectory() {
        let intermediateFile: URL = "/Intermediate/some"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/",
            source: "/",
            intermediate: "/Intermediate",
            bundle: nil
        )

        XCTAssertEqual(
            processor.process([intermediateFile]),
            []
        )
    }

    func testBundleFileIsSkippedForProductAndSourceSubdirectory() {
        let bundleFile: URL = "/Bundle/some"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/",
            source: "/",
            intermediate: "/Intermediate",
            bundle: "/Bundle"
        )

        XCTAssertEqual(
            processor.process([bundleFile]),
            []
        )
    }

    func testFiltersOutProductModulemap() throws {
        let dependencies = processor.process([
            "/Product/some.modulemap",
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testDoesNotFilterOutNonProductModulemap() throws {
        let dependencies = processor.process([
            "/Source/some.modulemap",
        ])

        XCTAssertEqual(dependencies, [.init(url: "/Source/some.modulemap", type: .source)])
    }

    func testFiltersOutXcodeFiles() throws {
        let dependencies = processor.process([
            "/Xcode/some",
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testFiltersOutIntermediateFiles() throws {
        let dependencies = processor.process([
            "/Intermediate/some",
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testFiltersOutBundleFiles() throws {
        let dependencies = processor.process([
            "/Bundle/some",
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testDoesNotFilterOutUnknownFiles() throws {
        let dependencies = processor.process([
            "/xxx/some",
        ])

        XCTAssertEqual(dependencies, [.init(url: "/xxx/some", type: .unknown)])
    }
}
