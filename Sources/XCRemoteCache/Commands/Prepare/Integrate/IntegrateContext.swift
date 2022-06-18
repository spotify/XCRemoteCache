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

struct IntegrateContext {
    let projectPath: URL
    let repoRoot: URL
    let binaries: XCRCBinariesPaths
    let mode: Mode
    let configOverride: URL
    let fakeSrcRoot: URL
    let output: URL?
}

extension IntegrateContext {
    init(
        input: String,
        repoRootPath: String,
        mode: Mode,
        configOverridePath: String,
        env: [String: String],
        binariesDir: URL,
        fakeSrcRoot: String,
        outputPath: String?
    ) throws {
        projectPath = URL(fileURLWithPath: input)
        let srcRoot = projectPath.deletingLastPathComponent()
        repoRoot = URL(fileURLWithPath: repoRootPath, relativeTo: srcRoot)
        self.mode = mode
        configOverride = URL(fileURLWithPath: configOverridePath, relativeTo: srcRoot)
        output = outputPath.flatMap(URL.init(fileURLWithPath:))
        self.fakeSrcRoot = URL(fileURLWithPath: fakeSrcRoot)
        binaries = XCRCBinariesPaths(
            prepare: binariesDir.appendingPathComponent("xcprepare"),
            cc: binariesDir.appendingPathComponent("xccc"),
            swiftc: binariesDir.appendingPathComponent("xcswiftc"),
            libtool: binariesDir.appendingPathComponent("xclibtool"),
            ld: binariesDir.appendingPathComponent("xcld"),
            ldplusplus: binariesDir.appendingPathComponent("xcldplusplus"),
            prebuild: binariesDir.appendingPathComponent("xcprebuild"),
            postbuild: binariesDir.appendingPathComponent("xcpostbuild")
        )
    }
}
