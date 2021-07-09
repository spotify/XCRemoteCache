@testable import XCRemoteCache

import XCTest


class FileDependenciesReaderTests: XCTestCase {

    private func generateFile(content: String, name: String) throws -> URL {
        let directory = NSTemporaryDirectory()
        let url = try NSURL.fileURL(withPathComponents: [directory, name]).unwrap()
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func prepareSwiftFile(name: String = #function) throws -> URL {
        let content = """
        /SomePath/Diffing.o : /SomePath/Diffing.swift /XcodePath/x86_64.swiftinterface /SomeOtherPath/module.modulemap
        /SomePath/Diffing~partial.swiftmodule : /SomePath/DiffingOther.swift /XcodePath/x86_64.swiftinterface\
        /SomeOtherPath/module.modulemap
        """
        return try generateFile(content: content, name: name)
    }

    private func prepareObjCFile(name: String = #function) throws -> URL {
        let content = """
        dependencies:  \\
          /SomePath/LOTValueCallback.m \\
          /OtherPath/LOTValueDelegate.h
        """
        return try generateFile(content: content, name: name)
    }

    func testReadingSwiftDFile() throws {
        let url = try prepareSwiftFile()
        let reader = FileDependenciesReader(url, accessor: FileManager.default)

        let readValue = try reader.findDependencies()

        XCTAssertEqual(
            Set(readValue),
            Set(["/SomePath/Diffing.swift", "/XcodePath/x86_64.swiftinterface", "/SomeOtherPath/module.modulemap"])
        )
    }

    func testReadingObjCDFile() throws {
        let url = try prepareObjCFile()
        let reader = FileDependenciesReader(url, accessor: FileManager.default)

        let readValue = try reader.findDependencies()

        XCTAssertEqual(Set(readValue), Set(["/SomePath/LOTValueCallback.m", "/OtherPath/LOTValueDelegate.h"]))
    }

    func testReadingObjCFileWithSpaceInPath() throws {
        let content = """
        /SomePath/Diffing.o : /SomePath\\ With\\ Space/Diffing.swift /XcodePath/x86_64.swiftinterface
        """
        let url = try generateFile(content: content, name: #function)
        let reader = FileDependenciesReader(url, accessor: FileManager.default)

        let readValue = try reader.findDependencies()

        XCTAssertEqual(Set(readValue), Set(["/SomePath With Space/Diffing.swift", "/XcodePath/x86_64.swiftinterface"]))
    }

    func testReadingSwiftFileWithSpaceInPath() throws {
        let content = """
        dependencies:  \\
          /SomePath\\ With\\ Space/LOTValueCallback.m \\
          /OtherPath/LOTValueDelegate.h
        """
        let url = try generateFile(content: content, name: #function)
        let reader = FileDependenciesReader(url, accessor: FileManager.default)

        let readValue = try reader.findDependencies()

        XCTAssertEqual(
            Set(readValue),
            Set(["/SomePath With Space/LOTValueCallback.m", "/OtherPath/LOTValueDelegate.h"])
        )
    }

    func testReadingObjCFileWithNoPaths() throws {
        let content = """
        /SomePath/Diffing.o : \\

        """
        let url = try generateFile(content: content, name: #function)
        let reader = FileDependenciesReader(url, accessor: FileManager.default)

        let readValue = try reader.findDependencies()

        XCTAssertEqual(Set(readValue), [])
    }

    func testReadingSwiftDepsWithBitcode() throws {
        let content = """
        /SomePath/Diffing.bc : /SomePath/Diffing.swift
        """
        let url = try generateFile(content: content, name: #function)
        let reader = FileDependenciesReader(url, accessor: FileManager.default)

        let readValue = try reader.findDependencies()

        XCTAssertEqual(Set(readValue), ["/SomePath/Diffing.swift"])
    }
}
