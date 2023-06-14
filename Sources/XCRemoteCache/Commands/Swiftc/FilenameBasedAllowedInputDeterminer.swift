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

/// Decides if an input to the compilation step should allow reusing the cached artifact
protocol AllowedInputDeterminer {
    /// Decides if the input file is allowed to be compiled, even not specified in the dependency list
    func allowedNonDependencyInput(file: URL) -> Bool
}

class FilenameBasedAllowedInputDeterminer: AllowedInputDeterminer {
    private let filenames: [String]

    init(_ filenames: [String]) {
        self.filenames = filenames
    }

    func allowedNonDependencyInput(file: URL) -> Bool {
        return filenames.contains(file.lastPathComponent)
    }
}
