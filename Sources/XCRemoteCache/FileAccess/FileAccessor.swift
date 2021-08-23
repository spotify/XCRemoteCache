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

/// Provides files write access
protocol FileWriter {
    /// Writes data bytes to a file
    /// - Parameters:
    ///   - toPath: path of the file
    ///   - content: content or `nil` if the file should be empty
    func write(toPath: String, contents: Data?) throws

    /// Deletes a file at given path
    func removeItem(atPath path: String) throws
}

/// Provides files read access
protocol FileReader {
    /// Reads content of a file
    /// - Parameters:
    ///   - atPath: path of the file
    /// - Returns content of a file or `nil` if the file doesn't exist
    /// - Throws when accessing a file failed
    func contents(atPath path: String) throws -> Data?

    /// Returns true if a file at given path exists
    /// - Parameter atPath: path of the file
    func fileExists(atPath path: String) -> Bool
}

typealias FileAccessor = FileWriter & FileReader

extension FileManager: FileWriter {
    func write(toPath path: String, contents: Data?) throws {
        try spt_writeToFile(atPath: path, contents: contents)
    }
}

extension FileManager: FileReader {}
