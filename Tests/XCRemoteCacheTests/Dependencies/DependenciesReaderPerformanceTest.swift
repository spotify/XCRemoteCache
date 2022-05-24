// Copyright (c) 2021 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

@testable import XCRemoteCache

import XCTest

class DependenciesReaderPerformanceTest: XCTestCase {

    private static let resourcesSubdirectory = "TestData/Dependencies/DependenciesReaderPerformanceTest"

    private func pathForTestData(name: String) throws -> URL {
        return try XCTUnwrap(Bundle.module.url(
            forResource: name,
            withExtension: "d",
            subdirectory: DependenciesReaderPerformanceTest.resourcesSubdirectory
        ))
    }

    func testFindDependenciesPerformance() throws {
        let file = try pathForTestData(name: "dependencies")
        let reader = FileDependenciesReader(file, accessor: FileManager.default)

        self.measure { // 0.005
            do {
                _ = try reader.findDependencies()
            } catch {
                print("Error reading dependencies")
            }
        }
    }

    func testReadRawFilePerformance() throws {
        let file = try pathForTestData(name: "dependencies")
        let reader = FileDependenciesReader(file, accessor: FileManager.default)

        self.measure { // 0.002
            do {
                _ = try reader.readRaw()
            } catch {
                print("Error reading dependencies")
            }
        }
    }

    func testGetFileDataPerformance() throws {
        let file = try pathForTestData(name: "dependencies")
        let reader = FileDependenciesReader(file, accessor: FileManager.default)

        self.measure { // 0.00008
            do {
                _ = try reader.getFileData()
            } catch {
                print("Error reading dependencies")
            }
        }
    }

    func testGetFileStringPerformance() throws {
        let file = try pathForTestData(name: "dependencies")
        let reader = FileDependenciesReader(file, accessor: FileManager.default)
        let fileData = try reader.getFileData()

        self.measure { // 0.00002
            do {
                _ = try reader.getFileStringFromData(fileData: fileData)
            } catch {
                print("Error reading dependencies")
            }
        }
    }

    func testGetYamlPerformance() throws { // 0.222
        let file = try pathForTestData(name: "dependencies")
        let reader = FileDependenciesReader(file, accessor: FileManager.default)
        let fileData = try reader.getFileData()
        let fileString = try reader.getFileStringFromData(fileData: fileData)

        self.measure { // 0.0022
            do {
                _ = try reader.getYaml(fileString: fileString)
            } catch {
                print("Error reading dependencies")
            }
        }
    }

    func testParseDependencyFileListUsingUTF8View() throws {
        let file = try pathForTestData(name: "dependencies")
        let reader = FileDependenciesReader(file, accessor: FileManager.default)
        let fileData = try reader.getFileData()
        let fileString = try reader.getFileStringFromData(fileData: fileData)
        let yaml = try reader.getYaml(fileString: fileString)

        guard let dependencies = yaml["dependencies"] else {
            XCTAssertTrue(false)
            return
        }

        self.measure { // 0.004
            let deps = reader.parseDependencyFileList(dependencies)
            XCTAssertTrue(deps.count == 1000)
        }
    }

    func testDeprecatedParseDependenciesFilesListOfAnObjectUsingUTF8View() throws {
        let file = try pathForTestData(name: "dependencies")
        let reader = FileDependenciesReader(file, accessor: FileManager.default)
        let fileData = try reader.getFileData()
        let fileString = try reader.getFileStringFromData(fileData: fileData)
        let yaml = try reader.getYaml(fileString: fileString)

        guard let dependencies = yaml["/This/Is/A/Path/To/Some/Object/objectfile.o"] else {
            XCTAssertTrue(false)
            return
        }

        self.measure { // 0.00048
            let deps = reader.parseDependencyFileList(dependencies)
            XCTAssertTrue(deps.count == 100)
        }
    }
}
