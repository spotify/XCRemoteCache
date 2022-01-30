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

/// Manages XCRemoteCache statistics: rests, print to the standard output etc
public class XCStats {
    private let outputEncoder: XCRemoteCacheEncoder
    private let reset: Bool

    public init(format: XCOutputFormat, reset: Bool) {
        self.reset = reset

        outputEncoder = XCEncoderAbstractFactory().build(for: format)
    }

    public func main() {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: XCStatsContext
        do {
            config = try XCRemoteCacheConfigReader(env: env, fileManager: fileManager).readConfiguration()
            try context = XCStatsContext(config, fileManager: fileManager)
        } catch {
            exit(1, "FATAL: Prepare initialization failed with error: \(error)")
        }

        do {
            let counterFactory: FileStatsCoordinator.CountersFactory = { file, count in
                ExclusiveFileCounter(ExclusiveFile(file, mode: .override), countersCount: count)
            }
            let statsCoordinator = try FileStatsCoordinator(
                statsLocation: context.statsDir,
                cacheLocationDir: context.cacheLocation,
                counterFactory: counterFactory,
                fileManager: fileManager
            )
            if reset {
                try statsCoordinator.reset()
            }
            let stats = try statsCoordinator.readStats()
            let output = try outputEncoder.encode(stats)
            print(output)
        } catch {
            exit(1, "XCStats failed with error: \(error)")
        }
    }
}
