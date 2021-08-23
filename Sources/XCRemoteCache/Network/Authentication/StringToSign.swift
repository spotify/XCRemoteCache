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

struct StringToSign {
    let algorithm = "AWS4-HMAC-SHA256"
    let terminationString = "aws4_request"
    let region: String
    let service: String
    let canonicalRequestHash: String
    let date: Date

    var credentialScope: String {
        "\(StringToSign.ISO8601DateDayOnlyFormatter.string(from: date))/" +
            "\(region)/" +
            "\(service)/" +
            "\(terminationString)"
    }

    var value: String {
        "\(algorithm)\n" +
            "\(StringToSign.ISO8601BasicFormatter.string(from: date))\n" +
            "\(credentialScope)\n" +
            "\(canonicalRequestHash)"
    }
}

extension StringToSign {
    static let ISO8601DateDayOnlyFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay]
        return formatter
    }()

    static let ISO8601BasicFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        return formatter
    }()
}
