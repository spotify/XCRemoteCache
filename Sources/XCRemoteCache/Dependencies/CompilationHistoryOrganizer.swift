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

/// Manages a file that collects all compilation invocations
protocol CompilationHistoryOrganizer {
    /// Cleans a state of clang history invocations
    func reset()
}

/// Manages a list of invocations stored in a file
class CompilationHistoryFileOrganizer: CompilationHistoryOrganizer {
    private let file: URL
    private let fileManager: FileManager

    init(_ file: URL, fileManager: FileManager) {
        self.file = file
        self.fileManager = fileManager
    }

    func reset() {
        fileManager.createFile(atPath: file.path, contents: nil, attributes: nil)
    }
}
