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

/// Representation of a single compilation dependency
public struct Dependency: Equatable {
    public enum Kind {
        case xcode
        case product
        case source
        case fingerprint
        case intermediate
        // Product of the target itself
        case ownProduct
        case unknown
    }

    public let url: URL
    public let type: Kind

    public init(url: URL, type: Kind) {
        self.url = url
        self.type = type
    }
}

/// Processes raw compilation URL dependencies from .d files
protocol DependencyProcessor {
    /// Processes a list of dependencies and provides a list of project-specific dependencies
    /// - Parameter files: raw dependency locations
    /// - Returns: array of project-specific dependencies
    func process(_ files: [URL]) -> [Dependency]
}

/// Classifies raw dependencies and strips irrelevant dependencies
class DependencyProcessorImpl: DependencyProcessor {
    private let xcodePath: String
    private let productPath: String
    private let sourcePath: String
    private let intermediatePath: String
    private let bundlePath: String?

    init(xcode: URL, product: URL, source: URL, intermediate: URL, bundle: URL?) {
        xcodePath = xcode.path.dirPath()
        productPath = product.path.dirPath()
        sourcePath = source.path.dirPath()
        intermediatePath = intermediate.path.dirPath()
        bundlePath = bundle?.path.dirPath()
    }

    func process(_ files: [URL]) -> [Dependency] {
        let dependencies = classify(files)
        return dependencies.filter(isRelevantDependency)
    }

    private func classify(_ files: [URL]) -> [Dependency] {
        return files.map { file -> Dependency in
            let filePath = file.resolvingSymlinksInPath().path
            if filePath.hasPrefix(xcodePath) {
                return Dependency(url: file, type: .xcode)
            } else if filePath.hasPrefix(intermediatePath) {
                return Dependency(url: file, type: .intermediate)
            } else if let bundle = bundlePath, filePath.hasPrefix(bundle) {
                // If a target produces a bundle, explicitly classify all
                // of products to distinguish from other targets products
                return Dependency(url: file, type: .ownProduct)
            } else if filePath.hasPrefix(productPath) {
                return Dependency(url: file, type: .product)
            } else if filePath.hasPrefix(sourcePath) {
                return Dependency(url: file, type: .source)
            } else {
                return Dependency(url: file, type: .unknown)
            }
        }
    }

    private func isRelevantDependency(_ dependency: Dependency) -> Bool {
        // Generated modulemaps may not be an actual dependency. Swift selects them as a
        // dependency because these contribute to the final module context but doesn't mean that given module has
        // been imported and it should invalidate current target when modified

        // TODO: Recognize if the generated module was actually imported and only then it should be considered
        // as a valid Dependency
        if dependency.type == .product && dependency.url.pathExtension == "modulemap" {
            return false
        }

        // Skip:
        // - A fingerprint generated includes Xcode version build number so no need to analyze prepackaged Xcode files
        // - All files in `*/Interemediates/*` - this file are created on-fly for a given target
        // - Some files may depend on its own product (e.g. .m may #include *-Swift.h) - we know products will match
        //   because in case of a hit, these will be taken from the artifact
        let irrelevantDependenciesType: [Dependency.Kind] = [.xcode, .intermediate, .ownProduct]
        return !irrelevantDependenciesType.contains(dependency.type)
    }
}

fileprivate extension String {
    func dirPath() -> String {
        hasSuffix("/") ? self : appending("/")
    }
}
