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
import XCRemoteCache

/// Wrapper for a `LD` program that copies the dynamic executable from a cached-downloaded location
/// Fallbacks to a standard `clang` when the Ramote cache is not applicable (e.g. modified sources)
public class XCLDMain {
    public func main() {
        let args = ProcessInfo().arguments
        var output: String?
        var filelist: String?
        var dependencyInfo: String?
        var i = 0
        while i < args.count {
            switch args[i] {
            case "-o":
                output = args[i + 1]
                i += 1
            case "-filelist":
                filelist = args[i + 1]
                i += 1
            case "-dependency_info":
                // Skip following `-Xlinker` argument. Sample call:
                // `clang -dynamiclib  ... -Xlinker -dependency_info -Xlinker /path/Target_dependency_info.dat`
                dependencyInfo = args[i + 2]
                i += 2
            default:
                break
            }
            i += 1
        }
        guard let outputInput = output, let filelistInput = filelist, let dependencyInfoInput = dependencyInfo else {
            let ldCommand = "clang"
            print("Fallbacking to compilation using \(ldCommand).")

            let args = ProcessInfo().arguments
            let paramList = [ldCommand] + args.dropFirst()
            let cargs = paramList.map { strdup($0) } + [nil]
            execvp(ldCommand, cargs)

            /// C-function `execv` returns only when the command fails
            exit(1)
        }


        // TODO: consider using `clang_command` from .rcinfo
        /// concrete clang path should be taken from the current toolchain
        let fallbackCommand = "clang"
        XCCreateBinary(
            output: outputInput,
            filelist: filelistInput,
            dependencyInfo: dependencyInfoInput,
            fallbackCommand: fallbackCommand,
            stepDescription: "xcld"
        ).run()
    }
}
