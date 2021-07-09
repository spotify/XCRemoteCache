import CommonCrypto
import Foundation

extension Data {

    func sha256() -> String {
        let hashData = digest(self)
        return hashData.map { String(format: "%02hhx", $0) }.joined()
    }

    private func digest(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = data.withUnsafeBytes {
            CC_SHA256($0.baseAddress, UInt32(data.count), &hash)
        }
        return Data(hash)
    }
}
