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

/// Replaces paths formats between generic (placeholders-based) and local
protocol DependenciesRemapper {
    /// Replaces all generic paths (with placeholders) to a local paths
    func replace(genericPaths: [String]) throws -> [String]
    /// Replaces all local paths to the generic dependencies paths
    func replace(localPaths: [String]) throws -> [String]
}

class DependenciesRemapperComposite: DependenciesRemapper {
    private let remappers: [DependenciesRemapper]

    init(_ remappers: [DependenciesRemapper]) {
        self.remappers = remappers
    }

    func replace(genericPaths: [String]) throws -> [String] {
        try remappers.reversed().reduce(genericPaths) { prev, mapper in
            try mapper.replace(genericPaths: prev)
        }
    }

    func replace(localPaths: [String]) throws -> [String] {
        try remappers.reduce(localPaths) { prev, mapper in
            try mapper.replace(localPaths: prev)
        }
    }
}

final class StringDependenciesRemapper: DependenciesRemapper {
    struct Mapping {
        let generic: String
        let local: String
    }

    private let mappings: [Mapping]

    init(mappings: [Mapping]) {
        self.mappings = mappings
    }

    func replace(genericPaths: [String]) throws -> [String] {
        return genericPaths.map { path in
            let localPath = mappings.reversed().reduce(path) { prevPath, mapping in
                prevPath.replacingOccurrences(of: mapping.generic, with: mapping.local)
            }
            return localPath
        }
    }

    func replace(localPaths: [String]) throws -> [String] {
        return localPaths.map { path in
            let result = mappings.reduce(path) { prevPath, mapping in
                prevPath.replacingOccurrences(of: mapping.local, with: mapping.generic)
            }
            return result
        }
    }
}
