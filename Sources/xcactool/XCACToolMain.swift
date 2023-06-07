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

            // TODO: take the actool from DERIVED_DATA (not global one)
            let ldCommand = "actool"
            print("Fallbacking to compilation using \(ldCommand).")

            let args = ProcessInfo().arguments
            let paramList = [ldCommand] + args.dropFirst()
            let cargs = paramList.map { strdup($0) } + [nil]
            execvp(ldCommand, cargs)

            /// C-function `execv` returns only when the command fails
            exit(1)
        }

        XCACTool(
            objcOutput: objcOutput,
            swiftOutput: swiftOutput
        ).run()
    }
}
