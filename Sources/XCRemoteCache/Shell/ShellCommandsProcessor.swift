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

/// Allows to patch Command arguments
protocol ArgsRewriter {
    /// Creates new invocation arguments
    /// - Parameter args: original command invocation args
    /// - Returns: command args with
    func applyArgsRewrite(_ args: [String]) throws -> [String]
}

/// Manages shell command invocations. Has a right to modify input args
/// and process command's result in a post-action
protocol ShellCommandsProcessor: ArgsRewriter {
    /// Called when the shell command finished with a success
    /// It adds a chance to read or modify output
    func postCommandProcessing() throws
}
