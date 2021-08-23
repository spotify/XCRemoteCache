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
@testable import XCRemoteCache

private func which(_ cmd: String) throws -> String {
    return try shellGetStdout("/usr/bin/which", args: [cmd])
}

/// Triggers a command without waiting it to finish
func startExec(_ cmd: String, args: [String] = [], inDir dir: String? = nil) throws -> Process {
    let absCmd = try cmd.starts(with: "/") ? cmd : which(cmd)

    let task = Process()

    task.launchPath = absCmd
    task.arguments = args
    task.standardError = Process().standardError
    task.standardOutput = Process().standardOutput
    if let dir = dir {
        task.currentDirectoryPath = dir
    }
    task.launch()
    return task
}

/// Waits for a process finish
func waitFor(_ task: Process) -> Int32 {
    task.waitUntilExit()
    return task.terminationStatus
}
