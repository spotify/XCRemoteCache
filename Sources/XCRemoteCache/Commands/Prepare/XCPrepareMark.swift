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
