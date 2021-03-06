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

enum SizeProviderError: Error {
    /// Unexpected format of the underlaying command (e.g. `du`)
    case unexpectedUnderlyingOutput
}

protocol SizeProvider {
    /// Returns size of the file taken on disk (real disk usage)
    /// - Parameter location: location to inspect
    /// - Returns: size of a file, or 0 if the location doesn't exist
    /// - Throws: `SizeProviderError` when an error occured
    func size(at location: URL) throws -> Int
}

/// Reads a size of a directory or a file using `du` command
class DiskUsageSizeProvider: SizeProvider {
    private let shell: ShellOutFunction
    private static let kilobytesToBytes = 1024

    init(shell: @escaping ShellOutFunction) {
        self.shell = shell
    }

    func size(at location: URL) throws -> Int {
        // `du` on macos doesn't support more granular output than 1024 bytes (-k)
        // Sample output of `du`:
        // > du -k -d 0 /some/some_dir_or_file
        // `2993136    /some/some_dir_or_file`
        let duOutput: String
        do {
            duOutput = try shell("du", ["-k", "-d", "0", location.path], nil, nil)
        } catch {
            // `du` returns with code >0 when the `location` doesn't exist
            return 0
        }
        guard let whitespaceIndex = duOutput.rangeOfCharacter(from: .whitespaces)?.lowerBound else {
            throw SizeProviderError.unexpectedUnderlyingOutput
        }
        guard let sizeInKb = Int(duOutput[..<whitespaceIndex]) else {
            throw SizeProviderError.unexpectedUnderlyingOutput
        }
        return sizeInKb * Self.kilobytesToBytes
    }
}
