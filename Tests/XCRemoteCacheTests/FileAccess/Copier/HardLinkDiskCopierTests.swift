@testable import XCRemoteCache
import XCTest

class HardLinkDiskCopierTests: FileXCTestCase {
    private static let SampleData = "Sample".data(using: .utf8)!

    func testCopiesFileToDir() throws {
        let workingDir = try prepareTempDir()
        let destinationDir = try fileManager.spt_createEmptyDir(workingDir.appendingPathComponent("dest"))
        let expectedDestinationFile = destinationDir.appendingPathComponent("empty.txt")
        let file = try fileManager.spt_createEmptyFile(workingDir.appendingPathComponent("empty.txt"))
        try fileManager.spt_createEmptyDir(destinationDir)
        let copier = HardLinkDiskCopier(fileManager: fileManager)

        try copier.copy(file: file, directory: destinationDir)

        XCTAssertTrue(fileManager.fileExists(atPath: expectedDestinationFile.path))
    }

    func testModifiedCopiedFileAffectsDestinationContent() throws {
        let workingDir = try prepareTempDir()
        let sourceFile = workingDir.appendingPathComponent("source")
        let destinationFile = workingDir.appendingPathComponent("destination")
        try fileManager.spt_writeToFile(atPath: sourceFile.path, contents: Data())
        let copier = HardLinkDiskCopier(fileManager: fileManager)

        try copier.copy(file: sourceFile, destination: destinationFile)
        try Self.SampleData.write(to: sourceFile)

        XCTAssertEqual(try Data(contentsOf: destinationFile), Self.SampleData)
    }
}
