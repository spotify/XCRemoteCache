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

/// Print current configuration to the console
public class XCConfig {
    private let outputEncoder: XCRemoteCacheEncoder

    public init(format: XCOutputFormat) {
        outputEncoder = XCEncoderAbstractFactory().build(for: format)
    }

    public func main() {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        do {
            config = try XCRemoteCacheConfigReader(env: env, fileManager: fileManager).readConfiguration()
        } catch {
            exit(1, "FATAL: Prepare initialization failed with error: \(error)")
        }

        do {
            let output = try outputEncoder.encode(config)
            print(output)
        } catch {
            exit(1, "XCInfo failed with error: \(error)")
        }
    }
}
