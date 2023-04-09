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

enum EnvironmentError: Error {
    case missingEnv(String)
}

extension Dictionary where Key == String, Value == String {
    func readEnv(key: String) -> URL? {
        guard let value = self[key].map(URL.init(fileURLWithPath:)) else {
            return nil
        }
        return value
    }

    func readEnv(key: String) throws -> URL {
        guard let value: URL = readEnv(key: key) else {
            throw EnvironmentError.missingEnv(key)
        }
        return value
    }

    func readEnv(key: String) -> String? {
        return self[key]
    }

    func readEnv(key: String) throws -> String {
        guard let value = self[key] else {
            throw EnvironmentError.missingEnv(key)
        }
        return value
    }

    func readEnv(key: String) throws -> Bool {
        guard let value = self[key] else {
            throw EnvironmentError.missingEnv(key)
        }
        return value == "YES"
    }
    
    func readEnv(key: String) throws -> Bool? {
        guard let value = self[key] else {
            return nil
        }
        return value == "YES"
    }
}
