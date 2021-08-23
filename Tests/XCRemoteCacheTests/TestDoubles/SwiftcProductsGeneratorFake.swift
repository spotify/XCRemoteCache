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

import Foundation
@testable import XCRemoteCache

/// A Fake that generates a full swift product (including required and optional swiftmodule files)
class SwiftcProductsGeneratorFake: SwiftcProductsGenerator {
    private let swiftmoduleDest: URL
    private let swiftmoduleObjCFile: URL
    private let dirAccessor: DirAccessor

    init(
        swiftmoduleDest: URL,
        swiftmoduleObjCFile: URL,
        dirAccessor: DirAccessor
    ) {
        self.swiftmoduleDest = swiftmoduleDest
        self.swiftmoduleObjCFile = swiftmoduleObjCFile
        self.dirAccessor = dirAccessor
    }

    func generateFrom(
        artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> URL {
        let swiftmoduleDestBasename = swiftmoduleDest.deletingPathExtension()
        for (ext, url) in artifactSwiftModuleFiles {
            try dirAccessor.write(
                toPath: swiftmoduleDestBasename.appendingPathExtension(ext.rawValue).path,
                contents: dirAccessor.contents(atPath: url.path)
            )
        }
        try dirAccessor.write(
            toPath: swiftmoduleObjCFile.path,
            contents: dirAccessor.contents(atPath: artifactSwiftModuleObjCFile.path)
        )
        return swiftmoduleDest.deletingLastPathComponent()
    }
}
