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

import Darwin
import Foundation
import os.log


private var processTag: String = ""

public func exit(_ exitCode: Int32, _ message: String) -> Never {
    os_log("%{public}@%{public}@", log: OSLog.default, type: .error, processTag, message)
    printError(errorMessage: message)
    exit(exitCode)
}

func defaultLog(_ message: String) {
    os_log("%{public}@%{public}@", log: OSLog.default, type: .default, processTag, message)
}

func errorLog(_ message: String) {
    os_log("%{public}@%{public}@", log: OSLog.default, type: .error, processTag, message)
}

func infoLog(_ message: String) {
    os_log("%{public}@%{public}@", log: OSLog.default, type: .info, processTag, message)
}

func debugLog(_ message: String) {
    os_log("%{public}@%{public}@", log: OSLog.default, type: .debug, processTag, message)
}

func printError(errorMessage: String) {
    fputs("error: \(processTag)\(errorMessage)\n", stderr)
}

func printWarning(_ message: String) {
    print("warning: \(processTag)\(message)")
}

/// Prints a message to the user. It shows in Xcode (if applies) or console output
/// - Parameter message: message to print
func printToUser(_ message: String) {
    print("[RC] \(message)")
}

func updateProcessTag(_ tag: String) {
    processTag = "(\(tag)) "
}
