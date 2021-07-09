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
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyUnsafeBytes.baseAddress, Int(keyUnsafeBytes.count), value.baseAddress, Int(value.count), out)
        }
    }
}
