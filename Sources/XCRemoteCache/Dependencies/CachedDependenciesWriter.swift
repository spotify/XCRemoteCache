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

/// Performant DependenciesWriter manager that reuses generated dependencies file
/// between multiple files that produce the same dependencies
/// This class is not thread-safe
class CachedFileDependenciesWriterFactory {
    private let dependencies: [URL]
    private let fileManager: FileManager
    private let factory: (URL, FileManager) -> DependenciesWriter
    private var templateDependencyFile: URL?

    init(
        dependencies: [URL],
        fileManager: FileManager,
        writerFactory: @escaping (URL, FileManager) -> DependenciesWriter
    ) {
        self.dependencies = dependencies
        self.fileManager = fileManager
        factory = writerFactory
    }

    func generate(output: URL) throws {
        if let template = templateDependencyFile {
            try fileManager.spt_forceCopyItem(at: template, to: output)
            return
        }
        // Generate the template file (happens only once)
        let writer = factory(output, fileManager)
        try writer.writeGeneric(dependencies: dependencies)
        if fileManager.fileExists(atPath: output.path) {
            // the file has been correctly created
            templateDependencyFile = output
        }
    }
}
