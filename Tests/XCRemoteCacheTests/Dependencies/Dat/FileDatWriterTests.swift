@testable import XCRemoteCache

import XCTest


class FileDatWriterTests: XCTestCase {

    private let file1 = URL(fileURLWithPath: "/file1")
    private let file2 = URL(fileURLWithPath: "/file2")
    private var workingDir: URL!
    private var workingFile: URL!
    private var fileManager: FileManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workingDir = URL(fileURLWithPath: NSTemporaryDirectory())
        fileManager = FileManager.default
    }

    override func tearDownWithError() throws {
        workingDir = nil
        if let fileToClean = workingFile {
            try? fileManager.removeItem(at: fileToClean)
            workingFile = nil
        }
        fileManager = nil
        try super.tearDownWithError()
    }

    func testSavesInput() throws {
        let inputs = [file1]
        let expectedData = try XCTUnwrap("\0cctools-959.0.1\0\u{10}/file1\0".data(using: .utf8))
        workingFile = workingDir.appendingPathComponent(#function)
        let writer = FileDatWriter(workingFile, fileManager: .default)

        try writer.enable(dependencies: inputs, outputs: [])

        XCTAssertEqual(fileManager.contents(atPath: workingFile.path), expectedData)
    }

    func testSavesInput2() throws {
        let inputs = [file1, file2]
        let expectedData = try XCTUnwrap("\0cctools-959.0.1\0\u{10}/file1\0\u{10}/file2\0".data(using: .utf8))
        workingFile = workingDir.appendingPathComponent(#function)
        let writer = FileDatWriter(workingFile, fileManager: .default)

        try writer.enable(dependencies: inputs, outputs: [])

        XCTAssertEqual(fileManager.contents(atPath: workingFile.path), expectedData)
    }

    func testSavesOutput() throws {
        let outputs = [file2]
        let expectedData = try XCTUnwrap("\0cctools-959.0.1\0\u{40}/file2\0".data(using: .utf8))
        workingFile = workingDir.appendingPathComponent(#function)
        let writer = FileDatWriter(workingFile, fileManager: .default)

        try writer.enable(dependencies: [], outputs: outputs)

        XCTAssertEqual(fileManager.contents(atPath: workingFile.path), expectedData)
    }

    func testSavesInputAndOutput() throws {
        let inputs = [file1]
        let outputs = [file2]
        let expectedData = try XCTUnwrap("\0cctools-959.0.1\0\u{10}/file1\0\u{40}/file2\0".data(using: .utf8))
        workingFile = workingDir.appendingPathComponent(#function)
        let writer = FileDatWriter(workingFile, fileManager: .default)

        try writer.enable(dependencies: inputs, outputs: outputs)

        XCTAssertEqual(fileManager.contents(atPath: workingFile.path), expectedData)
    }
}
