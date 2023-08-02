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
import xclibtoolSupport
import XCRemoteCache

public enum XCLibtoolMainError: Error {
    case missingOutput
    case unsupportedMode
}

/// Wrapper for a `libtool` program that copies the build executable (e.g. .a) from a cached-downloaded location
/// Fallbacks to a standard `libtool` when the Ramote cache is not applicable (e.g. modified sources)
public class XCLibtoolMain {
    public init() { }

    public func main() {
        let args = ProcessInfo().arguments

        do {
            let mode = try XCLibtoolHelper.buildMode(args: Array(args.dropFirst()))
            try XCLibtool(mode).run()
        } catch {
            exit(1, "Failed with: \(error). Args: \(args)")
        }
    }
}
