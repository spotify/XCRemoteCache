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

/// File paths remapper according the virtual file system mappings
/// - Warning: this class is not thread safe
class OverlayDependenciesRemapper: DependenciesRemapper {
    private let overlayReader: OverlayReader
    private var mappings: [OverlayMapping]?

    init(overlayReader: OverlayReader) {
        self.overlayReader = overlayReader
    }

    /// Lazily Reads mappings from a file
    /// - Warning: this function is not thread safe
    private func getMappings() throws -> [OverlayMapping] {
        guard let mappings = mappings else {
            let mappings = try overlayReader.provideMappings()
            self.mappings = mappings
            return mappings
        }
        return mappings
    }

    private func mapPath(
        _ path: String,
        source: KeyPath<OverlayMapping,URL>,
        destination: KeyPath<OverlayMapping,URL>
    ) throws -> String {
        guard let mapping = try getMappings().first(where: { $0[keyPath: source].path == path }) else {
            // TODO: support partial mappings, where a directory path can be replaced with some other directory
            // no direct mapping found
            return path
        }
        return mapping[keyPath: destination].path
    }

    func replace(genericPaths: [String]) throws -> [String] {
        try genericPaths.map {
            try mapPath($0, source: \.virtual, destination: \.local)
        }
    }

    func replace(localPaths: [String]) throws -> [String] {
        try localPaths.map {
            try mapPath($0, source: \.local, destination: \.virtual)
        }
    }
}
