@testable import XCRemoteCache
import XCTest

class MirroredLinkingSwiftcProductsGeneratorTests: FileXCTestCase {

    func testLinksProductsAccordingToLocationDir() throws {
        let workingDir = try prepareTempDir()
        let moduleFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule.swiftmodule"),
            content: "module"
        )
        let headerFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule-Swift.h"),
            content: "header"
        )
        let docsFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule.swiftdoc"),
            content: "docs"
        )
        let buildDir = workingDir.appendingPathComponent("build")
        let headersDir = workingDir.appendingPathComponent("headers")
        let expectedSwiftmoduleFile = buildDir
            .appendingPathComponent("MyModule.swiftmodule")
            .appendingPathComponent("arm64.swiftmodule")
        let expectedSwiftdocFile = buildDir
            .appendingPathComponent("MyModule.swiftmodule")
            .appendingPathComponent("arm64.swiftdoc")
        let artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL] = [
            .swiftmodule: moduleFile,
            .swiftdoc: docsFile,
        ]
        let expectedHeaderFile = headersDir.appendingPathComponent("MyModule-Swift.h")
        let generator = MirroredLinkingSwiftcProductsGenerator(
            arch: "arm64",
            buildDir: buildDir,
            headersDir: headersDir,
            diskCopier: HardLinkDiskCopier(fileManager: .default)
        )

        _ = try generator.generateFrom(
            artifactSwiftModuleFiles: artifactSwiftModuleFiles,
            artifactSwiftModuleObjCFile: headerFile
        )

        XCTAssertEqual(fileManager.contents(atPath: expectedSwiftmoduleFile.path), "module".data(using: .utf8))
        XCTAssertEqual(fileManager.contents(atPath: expectedSwiftdocFile.path), "docs".data(using: .utf8))
        XCTAssertEqual(fileManager.contents(atPath: expectedHeaderFile.path), "header".data(using: .utf8))
    }

    func testLinksSwiftSourceInfoToLocationDir() throws {
        let workingDir = try prepareTempDir()
        let moduleFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule.swiftmodule"),
            content: "module"
        )
        let headerFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule-Swift.h"),
            content: "header"
        )
        let docsFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule.swiftdoc"),
            content: "docs"
        )
        let sourceInfoFile = try fileManager.spt_createFile(
            workingDir.appendingPathComponent("MyModule.swiftsourceinfo"),
            content: "sourceInfo"
        )
        let artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL] = [
            .swiftmodule: moduleFile,
            .swiftdoc: docsFile,
            .swiftsourceinfo: sourceInfoFile,
        ]
        let buildDir = workingDir.appendingPathComponent("build")
        let headersDir = workingDir.appendingPathComponent("headers")
        let expectedSwiftSourceInfoFile = buildDir
            .appendingPathComponent("MyModule.swiftmodule")
            .appendingPathComponent("arm64.swiftsourceinfo")
        let generator = MirroredLinkingSwiftcProductsGenerator(
            arch: "arm64",
            buildDir: buildDir,
            headersDir: headersDir,
            diskCopier: HardLinkDiskCopier(fileManager: .default)
        )

        _ = try generator.generateFrom(
            artifactSwiftModuleFiles: artifactSwiftModuleFiles,
            artifactSwiftModuleObjCFile: headerFile
        )

        XCTAssertEqual(fileManager.contents(atPath: expectedSwiftSourceInfoFile.path), "sourceInfo".data(using: .utf8))
    }
}
