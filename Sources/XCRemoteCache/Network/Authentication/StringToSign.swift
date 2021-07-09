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
