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

enum SwiftmoduleFileExtensionType {
    case required
    case optional
}

// Type of the file that constitutes a full modulemap package
// RawValue corresponds to the file extension
enum SwiftmoduleFileExtension: String {
    case swiftmodule
    case swiftdoc
    case swiftsourceinfo
}

extension SwiftmoduleFileExtension {
    /// List of all swiftmodule extensions that should be copied to the artifact
    static let SwiftmoduleExtensions: [SwiftmoduleFileExtension: SwiftmoduleFileExtensionType] = [
        .swiftmodule: .required,
        .swiftdoc: .required,
        .swiftsourceinfo: .optional,
    ]
}
