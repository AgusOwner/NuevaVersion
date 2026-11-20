import Foundation

enum KeyAuthError: Error {
    case network(String)
    case api(String)
    case decoding
}

enum KeyAuthService {
    private static var sessionId: String?

    private static func post(params: [String: String]) async throws -> [String: Any] {
        guard let url = URL(string: KeyAuthConfig.apiBaseURL) else {
            throw KeyAuthError.network("Invalid API URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw KeyAuthError.network("Bad response")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyAuthError.decoding
        }
        return json
    }

    static func initSession() async throws {
        let params: [String: String] = [
            "type": "init",
            "ver": KeyAuthConfig.version,
            "hash": "",
            "name": KeyAuthConfig.name,
            "ownerid": KeyAuthConfig.ownerid
        ]
        let json = try await post(params: params)
        guard (json["success"] as? Bool) == true else {
            throw KeyAuthError.api(json["message"] as? String ?? "Init failed")
        }
        sessionId = json["sessionid"] as? String
    }

    static func license(key: String) async throws {
        if sessionId == nil {
            try await initSession()
        }
        var params: [String: String] = [
            "type": "license",
            "key": key,
            "name": KeyAuthConfig.name,
            "ownerid": KeyAuthConfig.ownerid
        ]
        if let sessionId {
            params["sessionid"] = sessionId
        }
        let json = try await post(params: params)
        guard (json["success"] as? Bool) == true else {
            throw KeyAuthError.api(json["message"] as? String ?? "Invalid key")
        }
    }
}
