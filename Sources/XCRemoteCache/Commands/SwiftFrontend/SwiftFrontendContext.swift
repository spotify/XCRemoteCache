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

struct SwiftFrontendContext {
    /// File lock used for synchronizing multiple invocations
    let invocationLockFile: URL
}

extension SwiftFrontendContext {
    init(_ swiftcContext: SwiftcContext, env: [String: String]) throws {
        /// The LLBUILD_BUILD_ID ENV that describes the swiftc (parent) invocation
        let llbuildId: String = try env.readEnv(key: "LLBUILD_BUILD_ID")
        invocationLockFile = Self.self.buildLlbuildIdSharedLockUrl(
            llbuildId: llbuildId,
            tmpDir: swiftcContext.tempDir
        )
    }

    /// Generate the filename to be used to sycnhronize mutliple swift-frontend invocations
    /// The same file is used in prebuild, xcswift-frontend and postbuild (to clean it up)
    static func buildLlbuildIdSharedLockUrl(llbuildId: String, tmpDir: URL) -> URL {
        return tmpDir.appendingPathComponent(llbuildId).appendingPathExtension("lock")
    }
}
