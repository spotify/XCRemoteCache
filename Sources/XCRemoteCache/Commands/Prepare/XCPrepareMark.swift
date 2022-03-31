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

/// Marks current sha as artifact-available on the remote side
public class XCPrepareMark {
    private let configuration: String
    private let platform: String
    private let xcode: String?
    private let commit: String?

    public init(
        configuration: String,
        platform: String,
        xcode: String?,
        commit: String?
    ) {
        self.configuration = configuration
        self.platform = platform
        self.xcode = xcode
        self.commit = commit
    }

    // swiftlint:disable:next function_body_length
    public func main() {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: PrepareMarkContext
        let xcodeVersion: String
        do {
            config = try XCRemoteCacheConfigReader(env: env, fileManager: fileManager).readConfiguration()
            context = try PrepareMarkContext(config)
            xcodeVersion = try xcode ?? XcodeProbeImpl(shell: shellGetStdout).read().buildVersion
        } catch {
            exit(1, "FATAL: Prepare initialization failed with error: \(error)")
        }

        do {
            let sessionFactory = DefaultURLSessionFactory(config: config)
            var awsV4Signature: AWSV4Signature?
            if !config.AWSAccessKey.isEmpty {
                awsV4Signature = AWSV4Signature(
                    secretKey: config.AWSSecretKey,
                    accessKey: config.AWSAccessKey,
                    securityToken: config.AWSSecurityToken,
                    region: config.AWSRegion,
                    service: config.AWSService,
                    date: Date(timeIntervalSinceNow: 0)
                )
            }
            let networkClient = NetworkClientImpl(
                session: sessionFactory.build(),
                retries: config.uploadRetries,
                fileManager: fileManager,
                awsV4Signature: awsV4Signature
            )
            let remoteNetworkClient = try RemoteNetworkClientAbstractFactory(
                mode: .producer,
                downloadStreamURL: context.recommendedCacheAddress,
                upstreamStreamURL: context.cacheAddresses,
                networkClient: networkClient
            ) { [configuration, platform] cacheAddress in
                // Prepare URLs don't include target name or envFingperint, which are valid only for a target level
                return URLBuilderImpl(
                    address: cacheAddress,
                    configuration: configuration,
                    platform: platform,
                    targetName: "",
                    xcode: xcodeVersion,
                    envFingerprint: "",
                    schemaVersion: config.schemaVersion
                )
            }.build()

            let gitCommit = try getCommitToMark(context: context, config: config)
            try remoteNetworkClient.createSynchronously(.marker(commit: gitCommit))
        } catch {
            exit(1, "Prepare failed with error: \(error)")
        }
    }

    private func getCommitToMark(context: PrepareMarkContext, config: XCRemoteCacheConfig) throws -> String {
        if let commit = commit {
            return commit
        }
        let gitClient = GitClientImpl(
            repoRoot: context.repoRoot.path,
            primary: GitBranch(repoLocation: config.primaryRepo, branch: config.primaryBranch),
            shell: shellGetStdout
        )
        return try gitClient.getCurrentSha()
    }
}
