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

class GitClientFake: GitClient {
    private let shaHistory: [(sha: String, date: Date)]
    private let primaryBranchIndex: Int

    init(shaHistory: [(sha: String, date: Date)], primaryBranchIndex: Int) {
        self.shaHistory = shaHistory
        self.primaryBranchIndex = primaryBranchIndex
    }

    func getCurrentSha() throws -> String {
        try (shaHistory.first?.sha).unwrap()
    }

    func getCommonPrimarySha() throws -> String {
        shaHistory[primaryBranchIndex].sha
    }

    func getShaDate(sha: String) throws -> Date {
        try (shaHistory.first(where: { $0.sha == sha })?.date).unwrap()
    }

    func getPreviousCommits(starting sha: String, maximum: Int) throws -> [String] {
        let index = try shaHistory.firstIndex(where: { $0.sha == sha }).unwrap()
        return shaHistory.suffix(from: index).suffix(maximum).map { $0.sha }
    }
}
