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

enum XCACToolContextError: Error {
    /// none of ObjC or Swift source output is defined
    case noOutputFile
}

struct ACToolContext {
    let tempDir: URL
    let objcOutput: URL?
    let swiftOutput: URL?
    let markerURL: URL
    /// Location (might include a symlink) to the unzipped artifact
    let activeArtifactLocation: URL

    init(
        config: XCRemoteCacheConfig,
        objcOutput: String?,
        swiftOutput: String?
    ) throws {
        self.objcOutput = objcOutput.map(URL.init(fileURLWithPath:))
        self.swiftOutput = swiftOutput.map(URL.init(fileURLWithPath:))

        // infer the target from either objc or swift
        guard let sourceOutputFile = self.objcOutput ?? self.swiftOutput else {
            throw XCACToolContextError.noOutputFile
        }

        // sourceOutputFile has a format $TARGET_TEMP_DIR/DerivedSources/GeneratedAssetSymbols.{swift|h}
        // That may be subject to change for other Xcode versions
        self.tempDir = sourceOutputFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        self.markerURL = tempDir.appendingPathComponent(config.modeMarkerPath)
        activeArtifactLocation = tempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent(ZipArtifactOrganizer.activeArtifactLocation)
    }
}
