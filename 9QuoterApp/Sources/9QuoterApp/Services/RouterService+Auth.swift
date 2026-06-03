import Foundation

extension RouterService {
    static func applyBasicAuth(_ credentials: BasicAuthCredentials, to request: inout URLRequest) {
        guard let header = credentials.authorizationHeader else { return }
        guard isLocalOrSecure(request.url) else { return }
        request.setValue(header, forHTTPHeaderField: "Authorization")
    }

    static func applyAuthCookie(token: String, to request: inout URLRequest) {
        request.setValue("locale=en; auth_token=\(token)", forHTTPHeaderField: "Cookie")
    }

    static func isLocalOrSecure(_ url: URL?) -> Bool {
        guard let url else { return false }
        if url.scheme == "https" { return true }
        guard url.scheme == "http" else { return false }
        let host = url.host ?? ""
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
}
