import Foundation

struct AWSV4SigningKey {

    let secretAccessKey: String
    let region: String
    let service: String
    let date: Date


    var value: [UInt8] {
        let formattedDate = StringToSign.ISO8601DateDayOnlyFormatter.string(from: date)

        let encryptedDate = HMAC.calcHMAC(keyString: "AWS4\(secretAccessKey)", value: formattedDate)
        let encryptedRegion = HMAC.calcHMAC(keyArray: encryptedDate, value: region)
        let encryptedService = HMAC.calcHMAC(keyArray: encryptedRegion, value: service)
        let encryptedSignature = HMAC.calcHMAC(keyArray: encryptedService, value: "aws4_request")

        return encryptedSignature
    }
}
