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
@testable import XCRemoteCache

// Thread-unsafe, in-memory lock
class FakeExclusiveFileAccessor: ExclusiveFileAccessor {
    private(set) var isLocked = false
    private var pattern: [LockFileContent]

    enum LockFileContent {
        case empty
        case nonEmptyForRead(URL)
        case nonEmptyForWrite(URL)

        func fileHandle() throws -> FileHandle {
            switch self {
            case .empty: return FileHandle.nullDevice
            case .nonEmptyForRead(let url): return try FileHandle(forReadingFrom: url)
            case .nonEmptyForWrite(let url): return try FileHandle(forWritingTo: url)
            }
        }
    }

    init(pattern: [LockFileContent] = []) {
        // keep in the reversed order to always pop
        self.pattern = pattern.reversed()
    }

    func exclusiveAccess<T>(block: (FileHandle) throws -> (T)) throws -> T {
        if isLocked {
            throw "FakeExclusiveFileAccessor lock is already locked"
        }
        defer {
            isLocked = false
        }
        isLocked = true
        let fileHandle = try (pattern.popLast() ?? .empty).fileHandle()
        return try block(fileHandle)
    }

}
