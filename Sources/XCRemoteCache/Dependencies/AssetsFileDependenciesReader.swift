// Copyright (c) 2023 Spotify AB.
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

import Foundation

/// Parser for `assetcatalog_dependencies` file
public class AssetsFileDependenciesReader: DependenciesReader {
    private let file: URL
    private let fileManager: FileManager

    public init(_ file: URL, accessor: FileManager) {
        self.file = file
        fileManager = accessor
    }

    public func findDependencies() throws -> [String] {
        return try Array(findAllDependencies())
    }

    public func findInputs() throws -> [String] {
        exit(1, "TODO: implement")
    }

    public func readFilesAndDependencies() throws -> [String : [String]] {
        return try ["": findAllDependencies()]
    }

    private func findAllDependencies() throws -> [String] {
        let fileData = try getFileData()
        // all dependency files are separated by the \0 byte
        let pathDatas = fileData.split(separator: 0x0)
        let paths = pathDatas
            .map { String(data: $0, encoding: .utf8)! }
            .map (URL.init(fileURLWithPath:))
        let xcassetsPaths = paths.filter { path in
            path.pathExtension == "xcassets"
        }
        return try xcassetsPaths.flatMap { try findAssetsContentJsons(xcasset: $0) }
    }

    private func findAssetsContentJsons(xcasset: URL) throws -> [String] {
        return try fileManager.recursiveItems(at: xcasset).filter { url in
            url.lastPathComponent == "Contents.json"
        }.map(\.path)
    }

    private func getFileData() throws -> Data {
        guard let fileData = fileManager.contents(atPath: file.path) else {
            throw DependenciesReaderError.readingError
        }
        return fileData
    }

}
