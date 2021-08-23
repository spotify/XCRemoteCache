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
@testable import XCRemoteCache

class DSYMOrganizerFake: DSYMOrganizer {
    let dSYMFile: URL?
    let fileManager: FileManager

    init(dSYMFile: URL?, fileManager: FileManager = .default) {
        self.dSYMFile = dSYMFile
        self.fileManager = fileManager
    }

    func relevantDSYMLocation() throws -> URL? {
        guard let url = dSYMFile else {
            return nil
        }
        fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
        return dSYMFile
    }

    func syncDSYM(artifactPath: URL) throws {
        guard let dsym = dSYMFile else {
            return
        }
        try fileManager.spt_forceLinkItem(at: artifactPath, to: dsym)
    }

    func cleanup() throws {
        guard let dsym = dSYMFile else {
            return
        }
        try fileManager.removeItem(at: dsym)
    }
}
