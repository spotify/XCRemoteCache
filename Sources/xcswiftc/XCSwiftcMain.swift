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

/// Wrapper for a `swiftc` that skips compilation and produces empty output files (.o). As a compilation dependencies
/// (.d) file, it copies all dependency files from the prebuild marker file
/// Fallbacks to a standard `swiftc` when the Ramote cache is not applicable (e.g. modified sources)
public class XCSwiftcMain {
    // swiftlint:disable:next function_body_length
    public func main() {
        let command = ProcessInfo().processName
        let args = ProcessInfo().arguments
        var objcHeaderOutput: String?
        var moduleName: String?
        var modulePathOutput: String?
        var filemap: String?
        var target: String?
        var swiftFileList: String?
        for i in 0..<args.count {
            let arg = args[i]
            switch arg {
            case "-emit-objc-header-path":
                objcHeaderOutput = args[i + 1]
            case "-module-name":
                moduleName = args[i + 1]
            case "-emit-module-path":
                modulePathOutput = args[i + 1]
            case "-output-file-map":
                filemap = args[i + 1]
            case "-target":
                target = args[i + 1]
            default:
                if arg.hasPrefix("@") && arg.hasSuffix(".SwiftFileList") {
                    swiftFileList = String(arg.dropFirst())
                }
            }
        }
        guard let objcHeaderOutputInput = objcHeaderOutput,
            let moduleNameInput = moduleName,
            let modulePathOutputInput = modulePathOutput,
            let filemapInput = filemap,
            let targetInputInput = target,
            let swiftFileListInput = swiftFileList
            else {
                print("Missing argument. Args: \(args)")
                exit(1)
        }
        let swiftcArgsInput = SwiftcArgInput(
            objcHeaderOutput: objcHeaderOutputInput,
            moduleName: moduleNameInput,
            modulePathOutput: modulePathOutputInput,
            filemap: filemapInput,
            target: targetInputInput,
            fileList: swiftFileListInput
        )
        XCSwiftc(
            command: command,
            inputArgs: swiftcArgsInput,
            dependenciesWriter: FileDependenciesWriter.init,
            touchFactory: FileTouch.init
        ).run()
    }
}
