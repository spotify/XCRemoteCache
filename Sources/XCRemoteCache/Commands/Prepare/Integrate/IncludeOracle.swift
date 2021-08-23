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

typealias OracleIdentifierType = String

/// Controls if the given type should be included or not
/// Example: controls if remote cache integration should be added for a given target or configuration
protocol IncludeOracle {
    /// Decides if a given type should be included or not
    /// - Parameter identifier: identifier of a type
    func shouldInclude(identifier: OracleIdentifierType) -> Bool
}

struct IncludeExcludeOracle: IncludeOracle {
    let excludes: [OracleIdentifierType]
    let includes: [OracleIdentifierType]


    func shouldInclude(identifier: OracleIdentifierType) -> Bool {
        // exclude array has precedence.
        if excludes.contains(identifier) {
            return false
        }
        guard !includes.isEmpty else {
            return true
        }
        return includes.contains(identifier)
    }
}
