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

class StaticSwiftcInputReader: SwiftcInputReader {
    private let moduleDependencies: URL?
    private let swiftDependencies: URL?
    private let compilationFiles: [SwiftFileCompilationInfo]

    init(
        moduleDependencies: URL?,
        swiftDependencies: URL?,
        compilationFiles: [SwiftFileCompilationInfo]
    ) {
        self.moduleDependencies = moduleDependencies
        self.swiftDependencies = swiftDependencies
        self.compilationFiles = compilationFiles
    }

    func read() throws -> SwiftCompilationInfo {
        return .init(
            info: .init(
                dependencies: moduleDependencies,
                swiftDependencies: swiftDependencies
            ),
            files: compilationFiles
        )
    }
}
