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

class DependenciesRemapperFake: DependenciesRemapper {
    private let baseURL: URL
    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func replace(genericPaths: [String]) -> [String] {
        genericPaths.map(baseURL.appendingPathComponent).map(\.path)
    }

    func replace(localPaths: [String]) -> [String] {
        localPaths.map { u -> String in
            let p = URL(fileURLWithPath: u, relativeTo: baseURL)
            return p.relativePath
        }
    }
}
