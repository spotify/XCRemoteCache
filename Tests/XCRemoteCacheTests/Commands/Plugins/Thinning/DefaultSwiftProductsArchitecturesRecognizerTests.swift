@testable import XCRemoteCache
import XCTest

class DefaultSwiftProductsArchitecturesRecognizerTests: FileXCTestCase {
    private var recognizer: DefaultSwiftProductsArchitecturesRecognizer!
    private var builtProductsDir: URL!
    private var swiftmoduleDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        recognizer = DefaultSwiftProductsArchitecturesRecognizer(dirAccessor: fileManager)
        builtProductsDir = try prepareTempDir().appendingPathComponent("builtProductsDir")
        swiftmoduleDir = builtProductsDir
            .appendingPathComponent("MyModule.swiftmodule")
    }

    func testRecognizesArchitecutres() throws {
        let swiftmoduleFile = swiftmoduleDir.appendingPathComponent("x86.swiftmodule")
        try fileManager.spt_createEmptyFile(swiftmoduleFile)

        let architectures = try recognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: "MyModule"
        )

        XCTAssertEqual(architectures, ["x86"])
    }

    func testRecognizesMultipleArchitecutres() throws {
        let swiftmoduleFile = swiftmoduleDir.appendingPathComponent("x86.swiftmodule")
        try fileManager.spt_createEmptyFile(swiftmoduleFile)
        let swiftmoduleSimFile = swiftmoduleDir.appendingPathComponent("x86_64-apple-ios-simulator.swiftmodule")
        try fileManager.spt_createEmptyFile(swiftmoduleSimFile)

        let architectures = try recognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: "MyModule"
        )

        XCTAssertEqual(architectures, ["x86", "x86_64-apple-ios-simulator"])
    }

    func testRecognizedArchitecutresAreNotDuplciated() throws {
        let swiftmodule = swiftmoduleDir.appendingPathComponent("x86.swiftmodule")
        let swiftmoduleDocs = swiftmoduleDir.appendingPathComponent("x86.swiftdocs")
        try fileManager.spt_createEmptyFile(swiftmodule)
        try fileManager.spt_createEmptyFile(swiftmoduleDocs)

        let architectures = try recognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: "MyModule"
        )

        XCTAssertEqual(architectures, ["x86"])
    }

    func testRecognizesArchitectureFromOverridesFiles() throws {
        let swiftmoduleMd5 = swiftmoduleDir.appendingPathComponent("x86.swiftmodule.md5")
        try fileManager.spt_createEmptyFile(swiftmoduleMd5)

        let architectures = try recognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: "MyModule"
        )

        XCTAssertEqual(architectures, ["x86"])
    }
}
