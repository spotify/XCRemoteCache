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

/// Removes Artifacts from Cache
public protocol CacheInvalidator {
    /// Invalidates and removes artifacts if they exist
    func invalidateArtifacts()
}

enum LocalCacheInvalidatorError: Error {
    case invalidDate
}

public class LocalCacheInvalidator: CacheInvalidator {

    private let localCacheURL: URL
    private let ageInDaysToInvalidate: Int

    private static let metaDir = "meta"
    private static let artifactsDir = "file"

    public init(localCacheURL: URL, maximumAgeInDays: Int) {
        self.localCacheURL = localCacheURL
        ageInDaysToInvalidate = maximumAgeInDays
    }

    public func invalidateArtifacts() {
        // Invalidate and remove artifacts if they exist
        try? removeFiles(from: Self.metaDir)
        try? removeFiles(from: Self.artifactsDir)
    }

    private func removeFiles(from: String) throws {
        // TODO: check if we can change to use .contentAccessDateKey property

        let metaFiles = try FileManager.default.contentsOfDirectory(
            at: localCacheURL.appendingPathComponent(from),
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        guard let oldestAllowedDate = Date().daysAgo(days: ageInDaysToInvalidate) else {
            throw LocalCacheInvalidatorError.invalidDate
        }
        try metaFiles.filter { file -> Bool in
            let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
            guard let creationDate = resourceValues.creationDate else {
                return false
            }
            return creationDate < oldestAllowedDate
        }.forEach { file in
            try FileManager.default.removeItem(at: file)
        }
    }
}
