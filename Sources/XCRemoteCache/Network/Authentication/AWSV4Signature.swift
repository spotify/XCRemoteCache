import Foundation

struct AWSV4Signature {

    let secretKey: String
    let accessKey: String
    let region: String
    let service: String
    let date: Date


    func addSignatureHeaderTo(request: inout URLRequest) {

        request.setValue(request.url?.host, forHTTPHeaderField: "host")
        request.setValue(StringToSign.ISO8601BasicFormatter.string(from: date), forHTTPHeaderField: "x-amz-date")
        request.setValue((request.httpBody ?? Data()).sha256(), forHTTPHeaderField: "x-amz-content-sha256")

        let canonicalRequest = CanonicalRequest(request: request)
        let stringToSign = StringToSign(region: region, service: service, canonicalRequestHash: canonicalRequest.hash, date: date)
        let awsV4SigningKey = AWSV4SigningKey(secretAccessKey: secretKey, region: region, service: service, date: date)
        let signature = HMAC.calcHMAC(keyArray: awsV4SigningKey.value, value: stringToSign.value).map { String(format: "%02hhx", $0) }.joined()

        let authValue =
            "AWS4-HMAC-SHA256 " +
                "Credential=\(accessKey)/\(stringToSign.credentialScope), " +
                "SignedHeaders=\(canonicalRequest.signedHeaders(headers: request.allHTTPHeaderFields)), " +
                "Signature=\(signature)"

        request.setValue(authValue, forHTTPHeaderField: "Authorization")
    }
}
