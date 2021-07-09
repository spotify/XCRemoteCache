@testable import XCRemoteCache

import XCTest

class ArtifactSwiftProductsBuilderImplTests: FileXCTestCase {
    private var rootDir: URL!
    private var moduleDir: URL!
    private var swiftmoduleFile: URL!
    private var swiftmoduleDocFile: URL!
    private var swiftmoduleSourceInfoFile: URL!
    private var workingDir: URL!
    private var builder: ArtifactSwiftProductsBuilderImpl!

    override func setUpWithError() throws {
        let rootDir = try prepareTempDir()
        moduleDir = rootDir.appendingPathComponent("Products")
        swiftmoduleFile = moduleDir.appendingPathComponent("MyModule.swiftmodule")
        swiftmoduleDocFile = moduleDir.appendingPathComponent("MyModule.swiftdoc")
        swiftmoduleSourceInfoFile = moduleDir.appendingPathComponent("MyModule.swiftsourceinfo")
        workingDir = rootDir.appendingPathComponent("working")
        builder = ArtifactSwiftProductsBuilderImpl(
            workingDir: workingDir,
            moduleName: "MyModule",
            fileManager: .default
        )
    }

    func testIncludesRequiredSwiftmoduleFiles() throws {
        try fileManager.spt_createFile(swiftmoduleFile, content: "swiftmodule")
        try fileManager.spt_createFile(swiftmoduleDocFile, content: "swiftdoc")
        let builderSwiftmoduleDir = builder.buildingArtifactSwiftModulesLocation().appendingPathComponent("arm64")
        let expectedBuildedSwiftmoduleFile = builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftmodule")
        let expectedBuildedSwiftmoduledocFile = builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftdoc")

        try builder.includeModuleDefinitionsToTheArtifact(arch: "arm64", moduleURL: swiftmoduleFile)

        XCTAssertEqual(fileManager.contents(atPath: expectedBuildedSwiftmoduleFile.path), "swiftmodule".data(using: .utf8))
        XCTAssertEqual(fileManager.contents(atPath: expectedBuildedSwiftmoduledocFile.path), "swiftdoc".data(using: .utf8))
    }

    func testIncludesAllSwiftmoduleFiles() throws {
        try fileManager.spt_createEmptyFile(swiftmoduleFile)
        try fileManager.spt_createEmptyFile(swiftmoduleDocFile)
        try fileManager.spt_createEmptyFile(swiftmoduleSourceInfoFile)
        let builderSwiftmoduleDir = builder.buildingArtifactSwiftModulesLocation().appendingPathComponent("arm64")
        let expectedBuildedSwiftmoduleFile = builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftmodule")
        let expectedBuildedSwiftmoduledocFile = builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftdoc")
        let expectedBuildedSwiftSourceInfoFile = builderSwiftmoduleDir.appendingPathComponent("MyModule.swiftsourceinfo")

        try builder.includeModuleDefinitionsToTheArtifact(arch: "arm64", moduleURL: swiftmoduleFile)

        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftmoduleFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftmoduledocFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBuildedSwiftSourceInfoFile.path))
    }

    func testFailsIncludingWhenMissingRequiredSwiftmoduleFiles() throws {
        XCTAssertThrowsError(try builder.includeModuleDefinitionsToTheArtifact(arch: "arm64", moduleURL: swiftmoduleFile))
    }
}
