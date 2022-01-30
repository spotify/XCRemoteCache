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

/// Switch between Online/Offline modes
public enum XCPrepareMode {
    /// Find the best common sha with primary with available marker on the remote cache server
    case online(configurations: [String], platforms: [String], customXcodeBuildNumber: String?)
    /// Skip making any HTTP requests and optimistically use a cache
    case offline
}

/// 1) Finds the best sha to use with Remote Cache. Saves it to the local file and prints to the console
/// 2) Compiles xccc wrapper from source
/// 3) Invalidates outdated local cache entries
public class XCPrepare {
    private let offline: Bool
    private let configurations: [String]
    private let platforms: [String]
    private let customXcodeBuildNumber: String?
    private let outputEncoder: XCRemoteCacheEncoder

    public init(_ mode: XCPrepareMode, format: XCOutputFormat) {
        switch mode {
        case .offline:
            offline = true
            configurations = []
            platforms = []
            customXcodeBuildNumber = nil
        case .online(let configurations, let platforms, let customXcodeBuildNumber):
            offline = false
            self.platforms = platforms
            self.configurations = configurations
            self.customXcodeBuildNumber = customXcodeBuildNumber
        }
        outputEncoder = XCEncoderAbstractFactory().build(for: format)
    }

    // swiftlint:disable:next function_body_length
    public func main() {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        var context: PrepareContext
        let xcodeVersion: String
        do {
            config = try XCRemoteCacheConfigReader(env: env, fileManager: fileManager).readConfiguration()
            context = try PrepareContext(config, offline: offline)
            xcodeVersion = try customXcodeBuildNumber ?? XcodeProbeImpl(shell: shellGetStdout).read().buildVersion
        } catch {
            exit(1, "FATAL: Prepare initialization failed with error: \(error)")
        }

        do {
            // TODO: Refactor to not pass empty arguments to `URLBuilderImpl`
            // URLs required by 'prepare' command are global for a project and don't required 'targetName'
            // or 'envFingerprint' - these are valid only for a target level requests
            let sessionFactory = DefaultURLSessionFactory(config: config)
            var awsV4Signature: AWSV4Signature?
            if !config.AWSAccessKey.isEmpty {
                awsV4Signature = AWSV4Signature(
                    secretKey: config.AWSSecretKey,
                    accessKey: config.AWSAccessKey,
                    region: config.AWSRegion,
                    service: config.AWSService,
                    date: Date(timeIntervalSinceNow: 0)
                )
            }
            let networkClient = NetworkClientImpl(
                session: sessionFactory.build(),
                retries: config.downloadRetries,
                fileManager: fileManager,
                awsV4Signature: awsV4Signature
            )
            let serverProbe = try LowestLatencyNetworkServerProbe(
                servers: context.cacheAddresses,
                healthPath: context.cacheHealthPath,
                probes: context.cacheHealthPathProbeCount,
                fallbackServer: context.recommendedCacheAddress,
                networkClient: networkClient
            )
            context.recommendedCacheAddress = try serverProbe.determineRemoteServer()
            var networkClients: [RemoteNetworkClient] = []
            for platform in platforms {
                for configuration in configurations {
                    let urlBuilder = URLBuilderImpl(
                        address: context.recommendedCacheAddress,
                        configuration: configuration,
                        platform: platform,
                        targetName: "",
                        xcode: xcodeVersion,
                        envFingerprint: "",
                        schemaVersion: config.schemaVersion
                    )
                    networkClients.append(RemoteNetworkClientImpl(networkClient, urlBuilder))
                }
            }
            let primaryGitBranch = GitBranch(repoLocation: context.primaryRepo, branch: context.primaryBranch)
            let gitClient = GitClientImpl(
                repoRoot: context.repoRoot.path,
                primary: primaryGitBranch,
                shell: shellGetStdout
            )
            let ccBuilder = TemplateBasedCCWrapperBuilder(
                clangCommand: config.clangCommand,
                markerPath: config.modeMarkerPath,
                cachedTargetMockFilename: config.thinTargetMockFilename,
                prebuildDFilename: config.prebuildDiscoveryPath,
                compilationHistoryFilename: config.compilationHistoryFile,
                shellOut: shellGetStdout,
                fileManager: fileManager
            )
            let cacheURL: URL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let localBuilder = LocalURLBuilderImpl(cachePath: cacheURL)
            let cacheAddress = localBuilder.location(for: context.recommendedCacheAddress)
            let cacheInvalidator = LocalCacheInvalidator(
                localCacheURL: cacheAddress,
                maximumAgeInDays: config.artifactMaximumAge
            )
            let fileAccessor = LazyFileAccessor(fileAccessor: FileManager.default)
            let globalCacheSwitcher = FileGlobalCacheSwitcher(context.remoteCommitLocation, fileAccessor: fileAccessor)

            let prepare = Prepare(
                context: context,
                gitClient: gitClient,
                networkClients: networkClients,
                ccBuilder: ccBuilder,
                fileAccessor: fileAccessor,
                globalCacheSwitcher: globalCacheSwitcher,
                cacheInvalidator: cacheInvalidator
            )
            let prepareResult = try prepare.prepare()
            try outputResult(prepareResult)
        } catch GitClientError.missingPrimaryRepo(let repo) {
            exit(1, """
            XCRemoteCache's `xcprepare` failed to find git remote with \(repo) address.\
            Check that your git configuration (`git remote -v`) specifies it.
            """)
        } catch {
            exit(1, "Prepare failed with error: \(error)")
        }
    }

    /// Prints to the standard output, result of the prepare command
    private func outputResult(_ result: PrepareResult) throws {
        let outputString = try outputEncoder.encode(result)
        print(outputString)
    }
}

extension PrepareResult: Encodable {
    enum CodingKeys: String, CodingKey {
        case result
        case commit
        case age
        case recommendedRemoteAddress = "recommended_remote_address"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let result: Bool
        let commit: String?
        let age: Int?
        let recommendedRemoteAddress: URL?
        switch self {
        case .failed:
            result = false
            commit = nil
            age = nil
            recommendedRemoteAddress = nil
        case .preparedFor(let sha, let remoteAddress):
            result = true
            commit = sha.sha
            age = sha.age
            recommendedRemoteAddress = remoteAddress
        }
        try container.encode(result, forKey: .result)
        try container.encode(commit, forKey: .commit)
        try container.encode(age, forKey: .age)
        try container.encode(recommendedRemoteAddress, forKey: .recommendedRemoteAddress)
    }
}

extension PrepareResult: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys)
        let result = try container.decode(Bool.self, forKey: .result)
        if result {
            let commit = try container.decode(String.self, forKey: .commit)
            let age = try container.decode(Int.self, forKey: .age)
            let recommendedRemoteAddress = try container.decode(URL.self, forKey: .recommendedRemoteAddress)
            self = .preparedFor(sha: ShaInfo(sha: commit, age: age), recommendedCacheAddress: recommendedRemoteAddress)
        } else {
            self = .failed
        }
    }
}
