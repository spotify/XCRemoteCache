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

import ArgumentParser
import Foundation
import XCRemoteCache

enum XCPrepareMainError: Error {
    case missingPlatform
    case missingConfiguration
}

/// Actions supported by xc-prepare
enum XCPrepareAction: String, ExpressibleByArgument {
    /// Setups RemoteCache session: finds the best commit sha to used by Remote Cache
    case prepare
    /// Marks the current commit to indicate succesful artifacts generation
    case mark
}

/// Extra command that should be called after each merge with primary branch
/// It fetches the most common commit sha on the
/// primary repo and finds a historical commit that has artifact on the remote server
/// Selected sha is saved as a file to let other commands know, which commit artifact is being used
/// To not introduce unnecessary Xcode steps invalidation, `mdate` of that file is set to a commit date
/// If the 'prepare' action succeds, it prints selected sha to the standard output
struct XCPrepareMain: ParsableCommand {

    private static func nonEmptyString(_ value: String) throws -> String {
        guard !value.isEmpty else {
            throw ValidationError("Unsupported empty string argument")
        }
        return value
    }

    private static func allCasesMessage<T: CaseIterable & RawRepresentable>(_ type: T.Type) -> String where T.RawValue == String {
        T.allCases.map(\.rawValue).map { "'\($0)'" } .joined(separator: ", ")
    }

    private static func toCase<T: RawRepresentable & CaseIterable>(_ value: String) throws -> T where T.RawValue == String {
        guard let mode = T(rawValue: value) else {
            throw ValidationError("Non supported value. Supported: \(allCasesMessage(T.self))")
        }
        return mode
    }

    static var configuration = CommandConfiguration(
        abstract: "Manage XCRemoteCache session.",
        subcommands: [Prepare.self, Mark.self, Offline.self, Stats.self, Config.self, Integrate.self],
        defaultSubcommand: Prepare.self
    )

    struct Prepare: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Find the latest commit sha for the Remote Cache.")

        @Option(help: "Build configuration")
        var configuration: [String]

        @Option(help: "Build Platform")
        var platform: [String]

        @Option(help: "Custom Xcode Build Number")
        var xcode: String?

        @Option(default: .yaml, help: "Output format")
        var format: XCOutputFormat

        func run() throws {
            guard !configuration.isEmpty else {
                throw XCPrepareMainError.missingConfiguration
            }
            guard !platform.isEmpty else {
                throw XCPrepareMainError.missingPlatform
            }
            let mode = XCPrepareMode.online(
                configurations: configuration,
                platforms: platform,
                customXcodeBuildNumber: xcode
            )
            XCPrepare(mode, format: format).main()
        }
    }

    struct Offline: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: """
            Offline mode - optimistically use the latest sha from the primary branch and first remote cache address.
            """)

        @Option(default: .yaml, help: "Output format")
        var format: XCOutputFormat

        func run() throws {
            XCPrepare(.offline, format: format).main()
        }
    }

    struct Mark: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Mark current sha as XCRemoteCache-ready.")

        @Option(help: "Build configuration")
        var configuration: String

        @Option(help: "Build Platform")
        var platform: String

        @Option(help: "Custom Xcode Build Number")
        var xcode: String?

        @Option(help: "Custom commit to mark")
        var commit: String?

        func run() throws {
            XCPrepareMark(configuration: configuration, platform: platform, xcode: xcode, commit: commit).main()
        }
    }

    struct Config: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Print the XCRemoteCache configuration")

        @Option(default: .yaml, help: "Output format")
        var format: XCOutputFormat

        func run() throws {
            XCConfig(format: format).main()
        }
    }

    struct Stats: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Offline mode - optimistically use the latest sha from the primary branch"
        )

        @Flag(help: "Resets")
        var reset: Bool

        @Option(default: .yaml, help: "Output format")
        var format: XCOutputFormat

        func run() throws {
            XCStats(format: format, reset: reset).main()
        }
    }

    struct Integrate: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Integrate XCRemoteCache into existing .xcodeproj"
        )

        @Option(help: ".xcodeproj location")
        var input: String

        @Option(help: "XCRemoteCache mode. Supported values: \(allCasesMessage(Mode.self))", transform: toCase)
        var mode: Mode

        @Option(default: "", help: "comma separated list of targets to integrate XCRemoteCache.")
        var targetsInclude: String

        @Option(default: "", help: """
        comma separated list of targets to not integrate XCRemoteCache. \
        Takes priority over --targets-include.
        """)
        var targetsExclude: String

        @Option(default: "", help: "comma separated list of configurations to integrate XCRemoteCache.")
        var configurationsInclude: String

        @Option(default: "Release", help: """
        comma separated list of configurations to not integrate XCRemoteCache. \
        Takes priority over --configurations-include.
        """)
        var configurationsExclude: String

        @Option(help: """
        [Producer only] The final target that generates cache artifacts. Once this target is finished, \
        no other targets are allowed to upload artifacts to the remote server for a given sha, \
        configuration and platform context.
        """)
        var finalProducerTarget: String?

        @Option(default: "Debug", help: """
        comma delimited list of configurations that need to have all artifacts \
        uploaded to the remote site before using given sha.
        """, transform: nonEmptyString)
        var consumerEligibleConfigurations: String

        @Option(default: "iphonesimulator", help: """
        comma delimited list of platforms that need to have all artifacts \
        uploaded to the remote site before using given sha.
        """, transform: nonEmptyString)
        var consumerEligiblePlatforms: String

        @Option(help: "Save the project with integrated XCRemoteCache to a separate location")
        var output: String?

        @Option(
            default: .user,
            help: """
            LLDBInit mode. Appends to .lldbinit a command required for debugging. \
            Supported values: \(allCasesMessage(LLDBInitMode.self))
            """,
            transform: toCase
        )
        var lldbInit: LLDBInitMode

        @Option(
            default: "/\(String(repeating: "x", count: 10))",
            help: """
            An arbitrary source location shared between producers and consumers. \
            Should be unique for a project.
            """,
            transform: nonEmptyString
        )
        var fakeSrcRoot: String


        func run() throws {
            XCIntegrate(
                input: input,
                mode: mode,
                configurationsExclude: configurationsExclude,
                configurationsInclude: configurationsInclude,
                targetsExclude: targetsExclude,
                targetsInclude: targetsInclude,
                finalProducerTarget: finalProducerTarget,
                consumerEligibleConfigurations: consumerEligibleConfigurations,
                consumerEligiblePlatforms: consumerEligiblePlatforms,
                lldbMode: lldbInit,
                fakeSrcRoot: fakeSrcRoot,
                output: output
            ).main()
        }
    }
}
