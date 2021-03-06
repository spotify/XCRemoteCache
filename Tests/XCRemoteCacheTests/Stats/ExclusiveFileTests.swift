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

@testable import XCRemoteCache
import XCTest

class ExclusiveFileTests: FileXCTestCase {
    private var url: URL!
    private var file: ExclusiveFile!
    @Atomic
    private var i = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        url = try prepareTempDir().appendingPathComponent("file")

        file = ExclusiveFile(url, mode: .override)
    }

    func testExclusiveAccessIsBlocking() throws {
        // Expected flow:
        // 1) Queue2 acquires a lock
        // 2) Queue2 sets i = 1 and waits 100ms
        // 3) Queue1 asks for accessing a file, but waits to acquire a log (locked by queue2)
        // 4) Queue2 increments i = 2 and releases a lock
        // 5) Queue1 accesses a file and verifies that i == 2
        // 6) The full scenario has to finish within 0.3s
        let exclusiveScope = expectation(description: "exclusiveScope")
        let finished = expectation(description: "finished")

        // Queue 1
        DispatchQueue.global(qos: .userInitiated).async {
            self.wait(for: [exclusiveScope], timeout: 0.3)
            try? self.file.exclusiveAccess { _ in
                XCTAssertEqual(self.i, 2)
                finished.fulfill()
            }
        }

        // Queue 2
        DispatchQueue.global(qos: .userInitiated).async {
            try? self.file.exclusiveAccess { _ in
                defer {
                    self.i = 2
                }
                self.i = 1
                exclusiveScope.fulfill()
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        wait(for: [finished], timeout: 0.3)
    }

    func testOverrideModeOverrideExistingFile() throws {
        let data = Data([1])
        file = ExclusiveFile(url, mode: .override)

        try file.exclusiveAccess { file in
            file.write(data)
        }
        try file.exclusiveAccess { file in
            file.write(data)
        }

        XCTAssertEqual(fileManager.contents(atPath: url.path), data)
    }

    func testAppendModeAddsAtTheEndOfFile() throws {
        let data = Data([1])
        file = ExclusiveFile(url, mode: .append)

        try file.exclusiveAccess { file in
            file.write(data)
        }
        try file.exclusiveAccess { file in
            file.write(data)
        }

        XCTAssertEqual(fileManager.contents(atPath: url.path), data + data)
    }
}
