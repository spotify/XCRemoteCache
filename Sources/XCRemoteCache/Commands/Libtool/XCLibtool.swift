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

/// Represents a mode that libtool was called
public enum XCLibtoolMode: Equatable {
    /// Creating a static library (ar format) from a set of .o input files
    case createLibrary(output: String, filelist: String, dependencyInfo: String)
    /// Creating a universal library (multiple-architectures) from a set of input .a static libraries
    case createUniversalBinary(output: String, inputs: [String])
    /// print the toolchain version
    case version
}

public class XCLibtool {
    private let logic: XCLibtoolLogic

    /// Intializer that depending on the argument mode, creates different libtool logic (kind of abstract factory)
    /// - Parameter mode: libtool mode to setup
    /// - Throws: XCLibtoolLogic specific errors if the mode arguments are invalid or inconsistent
    public init(_ mode: XCLibtoolMode) throws {
        switch mode {
        case .createLibrary(let output, let filelist, let dependencyInfo):
            logic = XCCreateBinary(
                output: output,
                filelist: filelist,
                dependencyInfo: dependencyInfo,
                fallbackCommand: "libtool",
                stepDescription: "Libtool"
            )
        case .createUniversalBinary(let output, let inputs):
            logic = try XCCreateUniversalBinary(
                output: output,
                inputs: inputs,
                toolName: "Libtool",
                fallbackCommand: "libtool"
            )
        case .version:
            logic = FallbackXCLibtoolLogic(fallbackCommand: "libtool")
        }
    }

    /// Executes the libtool logic
    public func run() {
        logic.run()
    }
}
