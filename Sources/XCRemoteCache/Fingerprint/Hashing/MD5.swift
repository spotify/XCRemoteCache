import CommonCrypto
import Foundation

/// Algorithm to hash data
public protocol HashingAlgorithm {
    init()
    func add(_ messageData: Data)
    func reset()
    func finalize() -> Data
}

class MD5Algorithm: HashingAlgorithm {
    private var context: CC_MD5_CTX

    required init() {
        context = CC_MD5_CTX()
        CC_MD5_Init(&context)
    }

    func reset() {
        context = CC_MD5_CTX()
        CC_MD5_Init(&context)
    }


    func add(_ messageData: Data) {
        if !messageData.isEmpty {
            messageData.withUnsafeBytes {
                _ = CC_MD5_Update(&context, $0.baseAddress, UInt32(messageData.count))
            }
        }
    }

    func finalize() -> Data {
        var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = CC_MD5_Final(&digest, &context)

        return Data(digest)
    }
}


extension HashingAlgorithm {
    func add(_ string: String) {
        add(string.data(using: .utf8)!)
    }

    func finalizeString() -> String {
        let digest = finalize()

        let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
        return hexDigest
    }
}
