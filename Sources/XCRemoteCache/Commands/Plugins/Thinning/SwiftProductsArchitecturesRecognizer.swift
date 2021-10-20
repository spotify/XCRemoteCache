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

// Recognizes
protocol SwiftProductsArchitecturesRecognizer {
    /// Scans Product dir to find which final archs Xcode generated for a target
    /// Sample architecture list: ["x86_64", "x86_64-apple-ios-simulator"]
    /// - Parameters:
    ///   - builtProductsDir: Location of the bulilt products dir to inspect - $(BUILT_PRODUCTS_DIR)
    ///   - moduleName: a name of the module to inspect
    /// - Returns: list of architectures
    func recognizeArchitectures(builtProductsDir: URL, moduleName: String) throws -> [String]
}

class DefaultSwiftProductsArchitecturesRecognizer: SwiftProductsArchitecturesRecognizer {
    /// Extension of a directory that contains all swift{module|doc|...} files
    private static let SwiftmoduleDirExtension = "swiftmodule"
    private let dirAccessor: DirAccessor

    init(dirAccessor: DirAccessor) {
        self.dirAccessor = dirAccessor
    }

    func recognizeArchitectures(builtProductsDir: URL, moduleName: String) throws -> [String] {
        /// Location where Xcode puts all swiftmodules
        let moduleDirectory = builtProductsDir
            .appendingPathComponent(moduleName)
            .appendingPathExtension(Self.SwiftmoduleDirExtension)
        // Skip folders (e.g. 'Project' dir that stores .sourceinfo, introduced in Xcode13)
        let productFiles = try dirAccessor.items(at: moduleDirectory).filter { url in
            try dirAccessor.itemType(atPath: url.path) == .file
        }
        /// files in a moduleDirectory have basename corresponding to the
        /// architecture (e.g. 'x86_64-apple-ios-simulator.swiftmodule', 'x86_64.swiftmodule' ...)
        let architectures = productFiles.map { file -> String in
            // recursively delete extensions to get rid of potential fingerprint overrides in a product directory
            var basenameFile = file
            while !basenameFile.pathExtension.isEmpty {
                basenameFile.deletePathExtension()
            }
            return basenameFile.lastPathComponent
        }
        // remove duplicates coming from files with different extensions (swiftmodule, swiftdoc etc.)
        return Set(architectures).sorted()
    }
}
