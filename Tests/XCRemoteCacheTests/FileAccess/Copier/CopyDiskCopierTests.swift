@testable import XCRemoteCache
import XCTest

class CopyDiskCopierTests: FileXCTestCase {
    private static let SampleData = "Sample".data(using: .utf8)!
    private var copier: CopyDiskCopier!
    private var workingDir: URL!
    private var emptySourceFile: URL!

    override func setUpWithError() throws {
        workingDir = try prepareTempDir()
        emptySourceFile = workingDir.appendingPathComponent("source")
        try fileManager.spt_writeToFile(atPath: emptySourceFile.path, contents: Data())
        copier = CopyDiskCopier(fileManager: fileManager)
    }

    func testModifiedCopiedFileDoesntAffectDestinationContent() throws {
        let destinationFile = workingDir.appendingPathComponent("destination")

        try copier.copy(file: emptySourceFile, destination: destinationFile)
        try Self.SampleData.write(to: emptySourceFile)

        XCTAssertEqual(try Data(contentsOf: destinationFile), Data())
    }

    func testCreatesIntermediateDirs() throws {
        let destinationFile = workingDir
            .appendingPathComponent("parent")
            .appendingPathComponent("destination")

        try copier.copy(file: emptySourceFile, destination: destinationFile)

        XCTAssertTrue(fileManager.fileExists(atPath: destinationFile.path))
    }

    func testOverridesDestination() throws {
        let destinationFile = workingDir.appendingPathComponent("destination")
        try fileManager.spt_writeToFile(atPath: destinationFile.path, contents: Self.SampleData)

        try copier.copy(file: emptySourceFile, destination: destinationFile)

        XCTAssertEqual(try Data(contentsOf: destinationFile), Data())
    }
}
