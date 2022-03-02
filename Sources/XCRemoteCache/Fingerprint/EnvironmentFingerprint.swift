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

/// Generates a fingerprint string of the environment (compilation context)
class EnvironmentFingerprintGenerator {
    /// Default ENV variables constituting the environment fingerprint
    private static let defaultEnvFingerprintKeys = [
        "GCC_PREPROCESSOR_DEFINITIONS",
        "CLANG_COVERAGE_MAPPING",
        "TARGET_NAME",
        "CONFIGURATION",
        "PLATFORM_NAME",
        "XCODE_PRODUCT_BUILD_VERSION",
        "CURRENT_PROJECT_VERSION",
        "DYLIB_COMPATIBILITY_VERSION",
        "DYLIB_CURRENT_VERSION",
        "PRODUCT_MODULE_NAME",
        "ARCHS",
    ]
    private let version: String
    private let customFingerprintEnvs: [String]
    private let env: [String: String]
    private let generator: FingerprintAccumulator
    private var generatedFingerprint: RawFingerprint?

    init(configuration: XCRemoteCacheConfig, env: [String: String], generator: FingerprintAccumulator) {
        self.generator = generator
        self.env = env
        customFingerprintEnvs = configuration.customFingerprintEnvs
        version = configuration.schemaVersion
    }

    func generateFingerprint() throws -> RawFingerprint {
        if let fingerprint = generatedFingerprint {
            return fingerprint
        }
        try fill(envKeys: Self.defaultEnvFingerprintKeys + customFingerprintEnvs)
        try generator.append(version)
        return try generator.generate()
    }

    /// Creates a fingerprint of the environemtn, by hashing all ENVs specified in keys
    private func fill(envKeys keys: [String]) throws {
        for key in keys {
            let value = env.readEnv(key: key) ?? ""
            try generator.append(value)
        }
    }
}
