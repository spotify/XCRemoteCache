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

@testable import XCRemoteCache
import XCTest


final class SwiftFrontendOrchestratorTests: FileXCTestCase {
    private let prohibitedAccessor = DisallowedExclusiveFileAccessor()
    private var nonEmptyFile: URL!
    private let maxLocking: TimeInterval = 10

    override func setUp() async throws {
        nonEmptyFile = try prepareTempDir().appendingPathComponent("lock.lock")
        try fileManager.write(toPath: nonEmptyFile.path, contents: "Done".data(using: .utf8))
    }
    func testRunsCriticalSectionImmediatellyForProducer() throws {
        let orchestrator = CommonSwiftFrontendOrchestrator(
            mode: .producer,
            action: .compile,
            lockAccessor: prohibitedAccessor,
            maxLockTimeout: maxLocking
        )

        var invoked = false
        try orchestrator.run {
            invoked = true
        }
        XCTAssertTrue(invoked)
    }

    func testRunsCriticalSectionImmediatellyForDisabledConsumer() throws {
        let orchestrator = CommonSwiftFrontendOrchestrator(
            mode: .consumer(commit: .unavailable),
            action: .compile,
            lockAccessor: prohibitedAccessor,
            maxLockTimeout: maxLocking
        )

        var invoked = false
        try orchestrator.run {
            invoked = true
        }
        XCTAssertTrue(invoked)
    }

    func testRunsEmitModuleLogicInAnExclusiveLock() throws {
        let lock = FakeExclusiveFileAccessor()
        let orchestrator = CommonSwiftFrontendOrchestrator(
            mode: .consumer(commit: .available(commit: "")),
            action: .emitModule,
            lockAccessor: lock,
            maxLockTimeout: maxLocking
        )

        var invoked = false
        try orchestrator.run {
            XCTAssertTrue(lock.isLocked)
            invoked = true
        }
        XCTAssertTrue(invoked)
    }

    func testCompilationInvokesCriticalSectionOnlyForNonEmptyLockFile() throws {
        let lock = FakeExclusiveFileAccessor(pattern: [.empty, .nonEmpty(nonEmptyFile)])
        let orchestrator = CommonSwiftFrontendOrchestrator(
            mode: .consumer(commit: .available(commit: "")),
            action: .compile,
            lockAccessor: lock,
            maxLockTimeout: maxLocking
        )

        var invoked = false
        try orchestrator.run {
            XCTAssertTrue(lock.isLocked)
            invoked = true
        }
        XCTAssertTrue(invoked)
    }

    func testExecutesActionWithoutLockIfLockingFileIsEmptyForALongTime() throws {
        let lock = FakeExclusiveFileAccessor(pattern: [])
        let orchestrator = CommonSwiftFrontendOrchestrator(
            mode: .consumer(commit: .available(commit: "")),
            action: .compile,
            lockAccessor: lock,
            maxLockTimeout: 0
        )

        var invoked = false
        try orchestrator.run {
            XCTAssertFalse(lock.isLocked)
            invoked = true
        }
        XCTAssertTrue(invoked)
    }
}

private class DisallowedExclusiveFileAccessor: ExclusiveFileAccessor {
    func exclusiveAccess<T>(block: (FileHandle) throws -> (T)) throws -> T {
        throw "Invoked ProhibitedExclusiveFileAccessor"
    }
}

// Thread-unsafe, in-memory lock
private class FakeExclusiveFileAccessor: ExclusiveFileAccessor {
    private(set) var isLocked = false
    private var pattern: [LockFileContent]

    enum LockFileContent {
        case empty
        case nonEmpty(URL)

        func fileHandle() throws -> FileHandle {
            switch self {
            case .empty: return FileHandle.nullDevice
            case .nonEmpty(let url): return try FileHandle(forReadingFrom: url)
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
