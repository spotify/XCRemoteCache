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

/// Wrapper for a `lipo` tool that creates a fat archive
public class XCLipo {
    private let logic: XCLibtoolLogic

    public init(
        output: String,
        inputs: [String],
        fallbackCommand: String,
        stepDescription: String
    ) throws {
        errorLog("\(output)")
        errorLog("\(inputs.joined(separator: ","))")
        logic = try XCCreateUniversalBinary(
            output: output,
            inputs: inputs,
            toolName: stepDescription,
            fallbackCommand: fallbackCommand
        )
    }

    /// Handles a `-create` action which is responsible to create a fat archive
    /// If remote cache can reuse artifacts from a remote cache, it just links any of input
    /// files to the destination (output) location because the binary in XCRC artifact already
    /// contains a fat library
    /// If a remote artifact cannot be reused, a fallback to the `lipo` command is performed
    public func run() {
        logic.run()
    }
}
