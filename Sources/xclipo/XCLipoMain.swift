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

/// Wrapper for a `lipo` program that links any of input binaries to the destination paths
/// Fallbacks to a standard `lipo` when the Ramote cache is not applicable (e.g. modified sources)
public class XCLipoMain {
    public init() { }

    public func main() {
        let args = ProcessInfo().arguments
        var output: String?
        var create = false
        var inputs: [String] = []

        var i = 1
        while i < args.count {
            switch args[i] {
            case "-output":
                output = args[i + 1]
                i += 1
            case "-create":
                create = true
            default:
                inputs.append(args[i])
            }
            i += 1
        }
        let lipoCommand = "lipo"
        guard let output = output, !inputs.isEmpty, create else {
            print("Fallbacking to compilation using \(lipoCommand).")

            let args = ProcessInfo().arguments
            let paramList = [lipoCommand] + args.dropFirst()
            let cargs = paramList.map { strdup($0) } + [nil]
            execvp(lipoCommand, cargs)

            /// C-function `execv` returns only when the command fails
            exit(1)
        }

        do {
            try XCLipo(
                output: output,
                inputs: inputs,
                fallbackCommand: lipoCommand,
                stepDescription: "xclipo"
            ).run()
        } catch {
            exit(1, "Failed with: \(error). Args: \(args)")
        }
    }
}
