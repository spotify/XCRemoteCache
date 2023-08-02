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

public enum XCLibtoolHelperError: Error {
    case missingOutput
    case unsupportedMode
}

public class XCLibtoolHelper {
    public static func buildMode(args: [String]) throws -> XCLibtoolMode {
        var output: String?
        // all input arguments are '*.a' or no path extension. Used to create an universal binary
        var inputLibraries: [String] = []
        var filelist: String?
        var dependencyInfo: String?
        var asksForVersion = false
        var i = 0
        while i < args.count {
            switch args[i] {
            case "-V":
                asksForVersion = true
            case "-o":
                output = args[i + 1]
                i += 1
            case "-filelist":
                filelist = args[i + 1]
                i += 1
            case "-dependency_info":
                dependencyInfo = args[i + 1]
                i += 1
            case "-static":
                () // just ignore it for now
            case let input where ["", "a"].contains(URL(string: args[i])?.pathExtension):
                // Support for static frameworks (no extension) and static libraries (.a)
                inputLibraries.append(input)
            default:
                break
            }
            i += 1
        }
        if asksForVersion {
            return .version
        }
        guard let outputInput = output else {
            throw XCLibtoolHelperError.missingOutput
        }

        let mode: XCLibtoolMode
        if let filelistInput = filelist, let dependencyInfoInput = dependencyInfo {
            // libtool is creating a library
            mode = .createLibrary(output: outputInput, filelist: filelistInput, dependencyInfo: dependencyInfoInput)
        } else if !inputLibraries.isEmpty {
            // multiple input libraries suggest creating an universal binary
            mode = .createUniversalBinary(output: outputInput, inputs: inputLibraries)
        } else {
            // unknown mode
            throw XCLibtoolHelperError.unsupportedMode
        }
        return mode
    }
}
