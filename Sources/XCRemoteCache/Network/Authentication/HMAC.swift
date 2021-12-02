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

import CommonCrypto
import Foundation

struct HMAC {

    static func calcHMAC(keyString: String, value: String) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        Self.calcHMAC(keyString: keyString, value: value, out: &out)
        return out
    }

    static func calcHMAC(keyArray: [UInt8], value: String) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        Self.calcHMAC(keyArray: keyArray, value: value, out: &out)
        return out
    }

    private static func calcHMAC(keyString: String, value: String, out: UnsafeMutableRawPointer!) {
        calcHMAC(keyData: keyString.data(using: .utf8)!, value: value, out: out)
    }

    private static func calcHMAC(keyData: Data, value: String, out: UnsafeMutableRawPointer!) {
        keyData.withUnsafeBytes { key in
            Self.calcHMAC(keyUnsafeBytes: key, value: value, out: out)
        }
    }

    private static func calcHMAC(keyArray: [UInt8], value: String, out: UnsafeMutableRawPointer!) {
        keyArray.withUnsafeBytes { key in
            Self.calcHMAC(keyUnsafeBytes: key, value: value, out: out)
        }
    }

    private static func calcHMAC(keyUnsafeBytes: UnsafeRawBufferPointer, value: String, out: UnsafeMutableRawPointer!) {
        value.data(using: .utf8)!.withUnsafeBytes { value in
            CCHmac(
                CCHmacAlgorithm(kCCHmacAlgSHA256),
                keyUnsafeBytes.baseAddress,
                Int(keyUnsafeBytes.count),
                value.baseAddress,
                Int(value.count),
                out
            )
        }
    }
}
