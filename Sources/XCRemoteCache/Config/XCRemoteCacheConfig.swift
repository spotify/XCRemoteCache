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

// swiftlint:disable file_length

import Foundation
import Yams

public enum XCRemoteCacheConfigError: Error {
    /// Obligatory configuration property is missing
    case missingConfiguration(name: String)
}

public struct XCRemoteCacheConfig: Encodable {
    /// Remote cache schema version. Bump that version if RC artifact generation introduces breaking changes
    let schemaVersion = "5"
    /// Mode: consumer|producer, defaults to consumer
    var mode: Mode = .consumer
    /// Address of all remote cache replicas. The best one (with the quickest response) will be chose in xcprepare step
    /// Required to be non-empty array
    var cacheAddresses: [String] = []
    /// Address of the remote cache to use in the consumer mode
    /// If not specified, the first item in `cacheAddresses` will be used
    var recommendedCacheAddress: String = ""
    /// Probe request path to the `cacheAddresses` (relative to `cacheAddresses`)
    /// that determines the best cache to use (with the lowest latency)
    var cacheHealthPath: String = "nginx-health"
    /// Number of `cacheAddresses` probe requests
    var cacheHealthPathProbeCount: Int = 3
    /// Filepath to the file to the remote commit sha
    var remoteCommitFile: String = "build/remote-cache/arc.rc"
    /// Filepath to create xccc wrapper (that value should be equal to Xcode's CC BuildSetting)
    var xcccFile: String = "build/bin/xccc"
    /// Path, relative to $TARGET_TEMP_DIR which specifies prebuild discovery .d file
    var prebuildDiscoveryPath: String = "prebuild.d"
    /// Path, relative to $TARGET_TEMP_DIR which specifies postbuild discovery .d file
    var postbuildDiscoveryPath: String = "postbuild.d"
    /// Path, relative to $TARGET_TEMP_DIR of a maker file to enable (when exists) or disable (when missing)
    /// Remote cache mode
    /// Includes a list of all allowed input files to use remote cache
    var modeMarkerPath: String = "rc.enabled"
    /// Command for a standard C compilation (cc)
    var clangCommand: String = "clang"
    /// Command for a standard Swift compilation (swiftc)
    var swiftcCommand: String = "swiftc"
    /// Command for a standard Swift frontend compilation (swift-frontend)
    var swiftFrontendCommand: String = "swift-frontend"
    /// Command for the assets catalog tool. By default takes from a symlink that points to the default Xcode location
    var actoolCommand: String = "/var/db/xcode_select_link/usr/bin/actool"
    /// Path of the primary repository that produces cache artifacts
    var primaryRepo: String = ""
    /// Main (primary) branch that produces cache artifacts (default to 'master')
    var primaryBranch: String = "master"
    /// Path to the git repo root
    var repoRoot: String = "."
    /// Number of historical commits to look for a cache artifacts
    var cacheCommitHistory: Int = 10
    /// Source root of the Xcode project
    var sourceRoot: String
    /// Fingerprint override extension (sample override `Module.swiftmodule/x86_64.swiftmodule.md5`)
    var fingerprintOverrideExtension: String = "md5"
    /// Optional configuration file that overrides project configuration
    var extraConfigurationFile: String = "user.rcinfo"
    /// Custom commit sha to publish artifact
    var publishingSha: String?
    /// Maximum age in days for artifact to be cached before being evicted
    var artifactMaximumAge: Int = 30
    /// Extra ENV keys that should be convoluted into the environment fingerprint
    var customFingerprintEnvs: [String] = []
    /// Root directory where all XCRemoteCache statistics (e.g. counters) are stored
    var statsDir: String = "~/.xccache"
    /// Number of retries for download requests
    var downloadRetries: Int = 0
    /// Number of retries for upload requests
    var uploadRetries: Int = 3
    /// Delay between retries in seconds
    var retryDelay: Double = 10.0
    /// Maximum number of simultaneous requests. 0 means no limits
    var uploadBatchSize: Int = 0
    /// Extra headers appended to all remote HTTP(S) requests
    var requestCustomHeaders: [String: String] = [:]
    /// Filename (without an extension) of the compilation input file that is used
    /// as a fake compilation for the forced-cached target (aka thin target)
    /// The filename has to be exclusive nor a suffix of any compilation file in a target
    var thinTargetMockFilename: String = "standin"
    /// A List of all targets that are not thin. If an empty array, all targets are meant to be non-thin
    /// A 'thin' target is a target-level mode that forces the cached artifact
    var focusedTargets: [String] = []
    ///  Disable cache for http requests to fecth metadata and download artifacts
    var disableHttpCache: Bool = false
    /// Path, relative to $TARGET_TEMP_DIR which gathers all compilation commands that should be e
    /// xecuted if a target switches to local compilation
    /// Example: A new `.swift` file invalidates remote arXcodeProjIntegrate.swifttifact and triggers local compilation
    /// When that happens, all previously skipped clang build steps
    /// need to be eventually called locally - this file lists all these commands
    var compilationHistoryFile: String = "history.compile"
    /// Timeout for remote response data interval (in seconds). If an interval between data chunks is
    /// longer than a timeout, a request fails
    var timeoutResponseDataChunksInterval: Double = 20
    /// It true, any observed request timeout switches off remote cache for all targets
    var turnOffRemoteCacheOnFirstTimeout: Bool = false
    /// List of all extensions that should carry over source fingerprints. Extensions of all product files that
    /// contain non-deterministic content (absolute paths, timestamp, etc) should be included
    /// .h files may contain absolute paths if NS_ENUM is used in a public API from Swift code
    var productFilesExtensionsWithContentOverride = ["swiftmodule", "h"]
    /// If true, plugins for thinning support should be enabled
    var thinningEnabled: Bool = false
    /// Module name of a target that works as a helper for thinned targets
    var thinningTargetModuleName: String = "ThinningRemoteCacheModule"
    /// Opt-in pretty json formatting for meta files
    var prettifyMetaFiles: Bool = false
    /// Secret key for AWS V4 Signature, if this is set the Authentication Header will be added
    var AWSSecretKey: String = ""
    /// Access key for AWS V4 Signature
    var AWSAccessKey: String = ""
    /// Temporary security token provided by the AWS Security Token Service
    var AWSSecurityToken: String?
    /// Region for AWS V4 Signature (e.g. `eu`)
    var AWSRegion: String = ""
    /// Service for AWS V4 Signature (e.g. `storage`)
    var AWSService: String = ""
    /// A dictionary of files path remapping that should be applied to make it absolute path agnostic on a list of
    /// dependencies. Useful if a project refers files out of repo root, either compilation files or precompiled
    /// dependencies. Keys represent generic replacement and values are substrings that should be replaced
    /// Example: for mapping `["COOL_LIBRARY": "/CoolLibrary"]`
    /// `/CoolLibrary/main.swift`will be represented as `$(COOL_LIBRARY)/main.swift`)
    /// Warning: remapping order is not-deterministic so avoid remappings with multiple matchings
    var outOfBandMappings: [String: String] = [:]
    /// If true, SSL certificate validation is disabled
    var disableCertificateVerification: Bool = false
    /// A feature flag to disable virtual file system overlay support (temporary)
    var disableVFSOverlay: Bool = false
    /// A list of extra ENVs that should be used as placeholders in the dependency list
    /// ENV rewrite process is optimistic - does nothing if an ENV is not defined in the pre/postbuild process
    var customRewriteEnvs: [String] = []
    /// Regexes of files that should not be included in a list of dependencies. Warning! Add entries here
    /// with caution - excluding dependencies that are relevant might lead to a target overcaching
    /// Note: The regex can match either partially or fully the filepath, e.g. `\\.modulemap$` will exclude
    /// all `.modulemap` files
    var irrelevantDependenciesPaths: [String] = []
    /// If true, do not fail `prepare` if cannot find the most recent common commits with the primary branch
    /// That might useful on CI, where a shallow clone is used
    var gracefullyHandleMissingCommonSha: Bool = false
    /// Enable experimental integration with swift driver, added in Xcode 14
    var enableSwiftDriverIntegration: Bool = false
}

extension XCRemoteCacheConfig {
    /// Merges existing config with the other config and returns a final result
    /// `other` scheme overrides existing configuration
    // swiftlint:disable:next function_body_length
    func merged(with scheme: ConfigFileScheme) -> XCRemoteCacheConfig {
        var merge = self
        merge.mode = scheme.mode ?? mode
        merge.recommendedCacheAddress = scheme.recommendedCacheAddress ?? recommendedCacheAddress
        merge.cacheAddresses = scheme.cacheAddresses ?? cacheAddresses
        merge.cacheHealthPath = scheme.cacheHealthPath ?? cacheHealthPath
        merge.cacheHealthPathProbeCount = scheme.cacheHealthPathProbeCount ?? cacheHealthPathProbeCount
        merge.remoteCommitFile = scheme.remoteCommitFile ?? remoteCommitFile
        merge.xcccFile = scheme.xcccFile ?? xcccFile
        merge.prebuildDiscoveryPath = scheme.prebuildDiscoveryPath ?? prebuildDiscoveryPath
        merge.postbuildDiscoveryPath = scheme.postbuildDiscoveryPath ?? postbuildDiscoveryPath
        merge.modeMarkerPath = scheme.modeMarkerPath ?? modeMarkerPath
        merge.clangCommand = scheme.clangCommand ?? clangCommand
        merge.swiftcCommand = scheme.swiftcCommand ?? swiftcCommand
        merge.actoolCommand = scheme.actoolCommand ?? actoolCommand
        merge.primaryRepo = scheme.primaryRepo ?? primaryRepo
        merge.primaryBranch = scheme.primaryBranch ?? primaryBranch
        merge.repoRoot = scheme.repoRoot ?? repoRoot
        merge.cacheCommitHistory = scheme.cacheCommitHistory ?? cacheCommitHistory
        merge.fingerprintOverrideExtension = scheme.fingerprintOverrideExtension ?? fingerprintOverrideExtension
        merge.extraConfigurationFile = scheme.extraConfigurationFile ?? extraConfigurationFile
        merge.publishingSha = scheme.publishingSha ?? publishingSha
        merge.artifactMaximumAge = scheme.artifactMaximumAge ?? artifactMaximumAge
        merge.customFingerprintEnvs = scheme.customFingerprintEnvs ?? customFingerprintEnvs
        merge.statsDir = scheme.statsDir ?? statsDir
        merge.downloadRetries = scheme.downloadRetries ?? downloadRetries
        merge.uploadRetries = scheme.uploadRetries ?? uploadRetries
        merge.retryDelay = scheme.retryDelay ?? retryDelay
        merge.uploadBatchSize = scheme.uploadBatchSize ?? uploadBatchSize
        merge.requestCustomHeaders = scheme.requestCustomHeaders ?? requestCustomHeaders
        merge.thinTargetMockFilename = scheme.thinTargetMockFilename ?? thinTargetMockFilename
        merge.focusedTargets = scheme.focusedTargets ?? focusedTargets
        merge.disableHttpCache = scheme.disableHttpCache ?? disableHttpCache
        merge.compilationHistoryFile = scheme.compilationHistoryFile ?? compilationHistoryFile
        merge.timeoutResponseDataChunksInterval =
            scheme.timeoutResponseDataChunksInterval ?? timeoutResponseDataChunksInterval
        merge.turnOffRemoteCacheOnFirstTimeout =
            scheme.turnOffRemoteCacheOnFirstTimeout ?? turnOffRemoteCacheOnFirstTimeout
        merge.productFilesExtensionsWithContentOverride =
            scheme.productFilesExtensionsWithContentOverride ?? productFilesExtensionsWithContentOverride
        merge.thinningEnabled = scheme.thinningEnabled ?? thinningEnabled
        merge.thinningTargetModuleName = scheme.thinningTargetModuleName ?? thinningTargetModuleName
        merge.prettifyMetaFiles = scheme.prettifyMetaFiles ?? prettifyMetaFiles
        merge.AWSAccessKey = scheme.AWSAccessKey ?? AWSAccessKey
        merge.AWSSecretKey = scheme.AWSSecretKey ?? AWSSecretKey
        merge.AWSSecurityToken = scheme.AWSSecurityToken ?? AWSSecurityToken
        merge.AWSRegion = scheme.AWSRegion ?? AWSRegion
        merge.AWSService = scheme.AWSService ?? AWSService
        merge.outOfBandMappings = scheme.outOfBandMappings ?? outOfBandMappings
        merge.disableCertificateVerification = scheme.disableCertificateVerification ?? disableCertificateVerification
        merge.disableVFSOverlay = scheme.disableVFSOverlay ?? disableVFSOverlay
        merge.customRewriteEnvs = scheme.customRewriteEnvs ?? customRewriteEnvs
        merge.irrelevantDependenciesPaths = scheme.irrelevantDependenciesPaths ?? irrelevantDependenciesPaths
        merge.gracefullyHandleMissingCommonSha =
            scheme.gracefullyHandleMissingCommonSha ?? gracefullyHandleMissingCommonSha
        merge.enableSwiftDriverIntegration = scheme.enableSwiftDriverIntegration ?? enableSwiftDriverIntegration
        return merge
    }

    /// Verifies all required properties and set defualts
    /// - Throws: `XCRemoteCacheConfigError` if the configuration is invalid
    /// - Returns: valid `XCRemoteCacheConfig` with configured defaults
    func verifyAndApplyDefaults() throws -> XCRemoteCacheConfig {
        var newConfig = self
        guard let fallbackCacheAddress = cacheAddresses.first else {
            throw XCRemoteCacheConfigError.missingConfiguration(name: "cache_addresses")
        }
        if recommendedCacheAddress.isEmpty {
            newConfig.recommendedCacheAddress = fallbackCacheAddress
        }
        return newConfig
    }
}

/// A scheme of the user-specific overrides of configs
struct ConfigFileScheme: Decodable {
    let mode: Mode?
    let recommendedCacheAddress: String?
    let cacheAddresses: [String]?
    let cacheHealthPath: String?
    let cacheHealthPathProbeCount: Int?
    let remoteCommitFile: String?
    let xcccFile: String?
    let prebuildDiscoveryPath: String?
    let postbuildDiscoveryPath: String?
    let modeMarkerPath: String?
    let clangCommand: String?
    let swiftcCommand: String?
    let actoolCommand: String?
    let primaryRepo: String?
    let primaryBranch: String?
    let repoRoot: String?
    let cacheCommitHistory: Int?
    let fingerprintOverrideExtension: String?
    let extraConfigurationFile: String?
    let publishingSha: String?
    let artifactMaximumAge: Int?
    let customFingerprintEnvs: [String]?
    let statsDir: String?
    let downloadRetries: Int?
    let uploadRetries: Int?
    let retryDelay: Double?
    let uploadBatchSize: Int?
    let requestCustomHeaders: [String: String]?
    let thinTargetMockFilename: String?
    let focusedTargets: [String]?
    let disableHttpCache: Bool?
    let compilationHistoryFile: String?
    let timeoutResponseDataChunksInterval: Double?
    let turnOffRemoteCacheOnFirstTimeout: Bool?
    let productFilesExtensionsWithContentOverride: [String]?
    let thinningEnabled: Bool?
    let thinningTargetModuleName: String?
    let prettifyMetaFiles: Bool?
    let AWSSecretKey: String?
    let AWSAccessKey: String?
    let AWSSecurityToken: String?
    let AWSRegion: String?
    let AWSService: String?
    let outOfBandMappings: [String: String]?
    let disableCertificateVerification: Bool?
    let disableVFSOverlay: Bool?
    let customRewriteEnvs: [String]?
    let irrelevantDependenciesPaths: [String]?
    let gracefullyHandleMissingCommonSha: Bool?
    let enableSwiftDriverIntegration: Bool?

    // Yams library doesn't support encoding strategy, see https://github.com/jpsim/Yams/issues/84
    enum CodingKeys: String, CodingKey {
        case mode
        case recommendedCacheAddress = "recommended_cache_address"
        case cacheAddresses = "cache_addresses"
        case cacheHealthPath = "cache_health_path"
        case cacheHealthPathProbeCount = "cache_health_path_probe_count"
        case remoteCommitFile = "remote_commit_file"
        case xcccFile = "xccc_file"
        case prebuildDiscoveryPath = "prebuild_discovery_path"
        case postbuildDiscoveryPath = "postbuild_discovery_path"
        case modeMarkerPath = "mode_marker_path"
        case clangCommand = "clang_command"
        case swiftcCommand = "swiftc_command"
        case actoolCommand = "actool_command"
        case primaryRepo = "primary_repo"
        case primaryBranch = "primary_branch"
        case repoRoot = "repo_root"
        case cacheCommitHistory = "cache_commit_history"
        case fingerprintOverrideExtension = "fingerprint_override_extension"
        case extraConfigurationFile = "extra_configuration_file"
        case publishingSha = "publishing_sha"
        case artifactMaximumAge = "artifact_maximum_age"
        case customFingerprintEnvs = "custom_fingerprint_envs"
        case statsDir = "stats_dir"
        case downloadRetries = "download_retries"
        case uploadRetries = "upload_retries"
        case retryDelay = "retry_delay"
        case uploadBatchSize = "upload_batch_size"
        case requestCustomHeaders = "request_custom_headers"
        case thinTargetMockFilename = "thin_target_mock_filename"
        case focusedTargets = "focused_targets"
        case disableHttpCache = "disable_http_cache"
        case compilationHistoryFile = "compilation_history_file"
        case timeoutResponseDataChunksInterval = "timeout_response_data_chunks_interval"
        case turnOffRemoteCacheOnFirstTimeout = "turn_off_remote_cache_on_first_timeout"
        case productFilesExtensionsWithContentOverride = "product_files_extensions_with_content_override"
        case thinningEnabled = "thinning_enabled"
        case thinningTargetModuleName = "thinning_target_module_name"
        case prettifyMetaFiles = "prettify_meta_files"
        case AWSSecretKey = "aws_secret_key"
        case AWSAccessKey = "aws_access_key"
        case AWSSecurityToken = "aws_security_token"
        case AWSRegion = "aws_region"
        case AWSService = "aws_service"
        case outOfBandMappings = "out_of_band_mappings"
        case disableCertificateVerification = "disable_certificate_verification"
        case disableVFSOverlay = "disable_vfs_overlay"
        case customRewriteEnvs = "custom_rewrite_envs"
        case irrelevantDependenciesPaths = "irrelevant_dependencies_paths"
        case gracefullyHandleMissingCommonSha = "gracefully_handle_missing_common_sha"
        case enableSwiftDriverIntegration = "enable_swift_driver_integration"
    }
}

enum XCRemoteCacheConfigReaderError: Error {
    case missingConfigurationFile(URL)
    case invalidConfiguration
}

class XCRemoteCacheConfigReader {
    /// Name of the configuration file, required in $(SRCROOT) location
    private static let configurationFile = ".rcinfo"
    private let srcRoot: String
    private let fileReader: FileReader
    private lazy var yamlDecorer = YAMLDecoder(encoding: .utf8)

    init(env: [String: String], fileReader: FileReader) throws {
        let explicitSrcRoot: String? = env.readEnv(key: "SRCROOT")
        srcRoot = explicitSrcRoot ?? FileManager.default.currentDirectoryPath
        self.fileReader = fileReader
    }

    init(srcRootPath srcRoot: String, fileReader: FileReader) {
        self.srcRoot = srcRoot
        self.fileReader = fileReader
    }

    // Reads the final configuration by loading all extra configs
    // until reaching a config that doesn't override `extraConfigurationFile`
    func readConfiguration() throws -> XCRemoteCacheConfig {
        let rootURL = URL(fileURLWithPath: srcRoot)
        let configURL = URL(fileURLWithPath: Self.configurationFile, relativeTo: rootURL)
        let userConfigs = try readUserConfig(configURL)
        var config = XCRemoteCacheConfig(sourceRoot: srcRoot).merged(with: userConfigs)
        var extraConfURL = URL(fileURLWithPath: config.extraConfigurationFile, relativeTo: rootURL)
        var visitedFiles = Set([configURL])
        while !visitedFiles.contains(extraConfURL) {
            do {
                let extraConfig = try readUserConfig(extraConfURL)
                debugLog("Reading extra configuration from \(extraConfURL)")
                config = config.merged(with: extraConfig)
                visitedFiles.insert(extraConfURL)
                // Advance extra configuration
                extraConfURL = URL(fileURLWithPath: config.extraConfigurationFile, relativeTo: rootURL)
            } catch {
                infoLog("Extra config override failed with \(error). Skipping extra configuration")
                // swiftlint:disable:next unneeded_break_in_switch
                break
            }
        }

        return try config.verifyAndApplyDefaults()
    }

    /// Reads user configuration from a file
    private func readUserConfig(_ file: URL) throws -> ConfigFileScheme {
        let configurationContent = try fileReader.contents(atPath: file.path)
        guard let configurationData = configurationContent else {
            throw XCRemoteCacheConfigReaderError.missingConfigurationFile(file)
        }
        guard let configurationString = String(data: configurationData, encoding: .utf8) else {
            throw XCRemoteCacheConfigReaderError.invalidConfiguration
        }
        return try yamlDecorer.decode(from: configurationString)
    }
}
