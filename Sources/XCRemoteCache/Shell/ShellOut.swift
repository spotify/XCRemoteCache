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

protocol ShellOut {
    /// Calls the command and replaces current process's streams
    /// In practive returns `Never` but to allow unit testing, it returns `Void`
    /// - Parameters:
    ///   - command: process path to execute
    ///   - invocationArgs: execution arguments
    func switchToExternalProcess(command: String, invocationArgs: [String])
    /// Calls the command and waits until it finishes
    /// - Parameters:
    ///   - command: process path to execute
    ///   - invocationArgs: execution arguments
    ///   - envs: process environment variables
    func callExternalProcessAndWait(command: String, invocationArgs: [String], envs: [String: String]) throws
}

class ProcessShellOut: ShellOut {
    func switchToExternalProcess(command: String, invocationArgs: [String]) {
        let paramList = [command] + invocationArgs
        let cargs = paramList.map { strdup($0) } + [nil]
        execvp(paramList[0], cargs)

        /// C-function `execvp` returns only when the command fails
        exit(1, "execvp(\(command)) unexpectedly returned")
    }

    func callExternalProcessAndWait(command: String, invocationArgs: [String], envs: [String: String]) throws {
        try shellCall(command, args: invocationArgs, inDir: nil, environment: envs)
    }
}
