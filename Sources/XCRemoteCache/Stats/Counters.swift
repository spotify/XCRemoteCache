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

enum CounterError: Error {
    /// File does not contain a valid string
    case fileCorrupted
    /// File does not contain a set of valid counters
    case counterCorrupted(counterValue: String)
    /// Canot dump counters to a file
    case invalidDumpData
}

/// Manages atomic operations for counters
/// Note: Counters are immune for schema change (new counters) but their positions have to be static
protocol Counters {
    /// Provides values of all counters (fills with 0 if not all counter are set)
    func readCounters() throws -> [Int]
    /// Writes values of all counters
    func writeCounters(_ counters: [Int]) throws
    /// Sets all counters to 0
    func reset() throws
    /// Incrememnts the counter at the position
    /// Requires position to be withing a range of a counter
    func bumpCounter(position: Int) throws
}

/// Counter backed by a file (with the exclusive access) with one counter per line
class ExclusiveFileCounter: Counters {
    private let accessor: ExclusiveFileAccessor
    /// Number of counters to track
    private let countersCount: Int

    init(_ accessor: ExclusiveFileAccessor, countersCount: Int) {
        self.accessor = accessor
        self.countersCount = countersCount
    }

    func readCounters() throws -> [Int] {
        return try accessor.exclusiveAccess { handle in
            try getCounters(file: handle)
        }
    }

    func writeCounters(_ counters: [Int]) throws {
        try accessor.exclusiveAccess { handle in
            try dump(file: handle, counters: counters)
        }
    }

    func bumpCounter(position: Int) throws {
        return try accessor.exclusiveAccess { handle in
            var counters = try getCounters(file: handle)
            counters[position] += 1
            try dump(file: handle, counters: counters)
        }
    }

    func reset() throws {
        return try accessor.exclusiveAccess { handle in
            let clearCounters = Array(repeating: 0, count: countersCount)
            try dump(file: handle, counters: clearCounters)
        }
    }

    private func getCounters(file: FileHandle) throws -> [Int] {
        let readData: Data?
        if #available(OSX 10.15.4, *) {
            readData = try file.readToEnd()
        } else {
            readData = file.readDataToEndOfFile()
        }
        guard let data = readData else {
            // Empty file (e.g. just created one)
            return Array(repeating: 0, count: countersCount)
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw CounterError.fileCorrupted
        }
        let counters: [Int] = try content.split(separator: "\n").map {
            guard let intValue = Int($0) else {
                throw CounterError.counterCorrupted(counterValue: String($0))
            }
            return intValue
        }
        switch counters.count {
        case countersCount:
            return counters
        case 0..<countersCount:
            // Support counters schema update: padding new counters with 0
            return counters + Array(repeating: 0, count: countersCount - counters.count)
        default:
            // trim additional counters
            return counters.suffix(countersCount)
        }
    }


    private func dump(file: FileHandle, counters: [Int]) throws {
        // go to the beginning of the file
        if #available(OSX 10.15, *) {
            try file.seek(toOffset: 0)
        } else {
            file.seek(toFileOffset: 0)
        }

        let lines = counters.map(String.init)
        let content = lines.joined(separator: "\n")
        guard let data = content.data(using: .utf8) else {
            throw CounterError.invalidDumpData
        }
        file.write(data)
        file.truncateFile(atOffset: UInt64(data.count))
    }
}
