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
import XCRemoteCache

/// Wrapper for a `actool`
public class XCACToolMain {
    public func main() {
        let args = ProcessInfo().arguments
        var objcOutput: String?
        var swiftOutput: String?
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--generate-swift-asset-symbols":
                swiftOutput = args[i + 1]
                i += 1
            case "--generate-objc-asset-symbols":
                objcOutput = args[i + 1]
                i += 1
            default:
                break
            }
            i += 1
        }
        if objcOutput == nil && swiftOutput == nil {
            // no need to run the wrapper body. Possible scenarios:
            // - Xcode 14 or older
            // - probe invocation (e.g. --version)
            // - compiling asset(s)
            // etc.

            let acCommand = "/var/db/xcode_select_link/usr/bin/actool"

            let args = ProcessInfo().arguments
            let paramList = [acCommand] + args.dropFirst()
            let cargs = paramList.map { strdup($0) } + [nil]
            execvp(acCommand, cargs)

            /// C-function `execv` returns only when the command fails
            exit(1)
        }

        do {
            try XCACTool(
                args: args,
                objcOutput: objcOutput,
                swiftOutput: swiftOutput
            ).run()
        } catch {
            exit(1, "Failed with: \(error). Args: \(args)")
        }
    }
}
