import Foundation

struct CanonicalRequest {

    let request: URLRequest

    var value: String? {
        guard let httpMethod = request.httpMethod,
            let url = request.url,
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                return nil
        }
        let path: String
        if url.path.isEmpty {
            path = "/"
        } else {
            path = url.path
        }
        return
            "\(httpMethod)\n" +
                "\(path)\n" +
                "\(canonicalQueryString(urlComponents: urlComponents))\n" +
                "\(canonicalHeaders(headers: request.allHTTPHeaderFields))\n\n" +
                "\(signedHeaders(headers: request.allHTTPHeaderFields))\n" +
                "\(request.httpBody?.sha256() ?? Data().sha256())"
    }

    var hash: String {
        value?.data(using: .utf8)!.sha256() ?? ""
    }

    private func canonicalQueryString(urlComponents: URLComponents) -> String {
        return urlComponents.queryItems?.map { item -> (String, String) in
            (item.name, item.value ?? "")
        }.sorted(by: { first, second in
            first.0 < second.0
        }).reduce(into: "") { result, value in
            if let resultInitialized = result, !resultInitialized.isEmpty {
                result = "\(resultInitialized)&"
            }
            result = "\(result ?? "")\(value.0)=\(value.1)"
        } ?? ""
    }

    private func canonicalHeaders(headers: [String: String]?) -> String {
        return headers?.keys.map { key in
            (
                key.lowercased().trimmingCharacters(in: .whitespaces),
                headers?[key]?.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "[\\s]{2,}", with: " ", options: [.regularExpression]) ?? ""
            )
        }.sorted(by: { first, second in
            first.0 < second.0
        }).reduce(into: "") { result, value in
            if let resultInitialized = result, !resultInitialized.isEmpty {
                result = "\(resultInitialized)\n"
            }
            result = "\(result ?? "")\(value.0):\(value.1)"
        } ?? ""
    }

    func signedHeaders(headers: [String: String]?) -> String {
        return headers?.keys.map { key in
            key.lowercased().trimmingCharacters(in: .whitespaces)
        }.sorted(by: { first, second in
            first < second
        }).reduce(into: "") { result, value in
            if let resultInitialized = result, !resultInitialized.isEmpty {
                result = "\(resultInitialized);"
            }
            result = "\(result ?? "")\(value)"
        } ?? ""
    }
}
